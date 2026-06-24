//
//  IPCHelpers.swift
//  TestableUIKitMCPCore
//
//  TestableUIKit MCP Server — 純粋ヘルパー関数（Swift 版）
//
//  HTTP IPC の URL 構築・接続先解決・perform payload 組み立て・
//  simctl コマンド生成・loopback 判定。外部 SwiftPM 依存なし
//  （Foundation のみ）。Simulator / DemoApp / HTTP 接続不要で単体テスト可能。
//
//  移植元: mcp_server/ipc_helpers.py（Python）。挙動を 1:1 で対応させる。
//

import Foundation

public enum IPCHelpers {

  // ================================================================
  // 定数
  // ================================================================

  /// 既定の IPC 接続先ホスト
  public static let defaultIPCHost = "localhost"
  /// 既定の IPC 接続先ポート
  public static let defaultIPCPort = 8888

  /// 接続先ホスト上書き用の環境変数名（Design D: LAN 越し IPC）
  public static let envIPCHost = "TESTABLE_IPC_HOST"
  /// 接続先ポート上書き用の環境変数名
  public static let envIPCPort = "TESTABLE_IPC_PORT"

  // ================================================================
  // resolveIPCHostPort
  // ================================================================

  /// 環境変数から IPC 接続先の host・port を解決する。
  ///
  /// 環境変数が未設定の場合は既定値（localhost:8888）を返す。
  /// ポート文字列が整数に変換できない場合は既定ポートにフォールバックする。
  ///
  /// - Parameter env: 参照する環境変数 dict（テスト時に注入）
  /// - Returns: (host, port) のタプル
  public static func resolveIPCHostPort(
    env: [String: String]
  ) -> (host: String, port: Int) {
    let host = env[envIPCHost] ?? defaultIPCHost
    let portStr = env[envIPCPort] ?? String(defaultIPCPort)
    let port = Int(portStr) ?? defaultIPCPort
    return (host, port)
  }

  // ================================================================
  // buildBaseURL
  // ================================================================

  /// IPC サーバーのベース URL を組み立てる（末尾スラッシュなし）。
  public static func buildBaseURL(
    host: String = defaultIPCHost,
    port: Int = defaultIPCPort
  ) -> String {
    return "http://\(host):\(port)"
  }

  // ================================================================
  // buildScreenshotURL
  // ================================================================

  /// GET /screenshot エンドポイントの URL を組み立てる。
  public static func buildScreenshotURL(
    host: String = defaultIPCHost,
    port: Int = defaultIPCPort
  ) -> String {
    return "\(buildBaseURL(host: host, port: port))/screenshot"
  }

  // ================================================================
  // buildPerformPayload
  // ================================================================

  /// POST /perform の request body（JSON 文字列）を構築する。
  ///
  /// キー順は testID → commandName → parameters で固定（決定的）。
  /// parameters は呼び出し側が JSON にシリアライズ済みの文字列を渡す。
  /// nil の場合は JSON の `null` を埋め込む。
  ///
  /// - Parameters:
  ///   - testID: コンポーネントの testID（例: "scene.auth.loginButton"）
  ///   - commandName: コマンド名（"getState" / "tap" / "setProperty" など）
  ///   - parametersJSON: シリアライズ済みパラメータ JSON（省略時 null）
  /// - Returns: `{"testID":...,"commandName":...,"parameters":...}` 形式の JSON 文字列
  public static func buildPerformPayload(
    testID: String,
    commandName: String,
    parametersJSON: String? = nil
  ) -> String {
    let params = parametersJSON ?? "null"
    return "{\"testID\":\(jsonEscaped(testID)),"
      + "\"commandName\":\(jsonEscaped(commandName)),"
      + "\"parameters\":\(params)}"
  }

  // ================================================================
  // buildSimctlScreenshotCommand
  // ================================================================

  /// `simctl io booted screenshot` コマンドを組み立てる（Simulator 専用）。
  ///
  /// - Parameter outputPath: スクリーンショットの保存先ファイルパス
  /// - Returns: Process / subprocess に渡せる引数リスト
  public static func buildSimctlScreenshotCommand(outputPath: String) -> [String] {
    return ["xcrun", "simctl", "io", "booted", "screenshot", outputPath]
  }

  // ================================================================
  // isLoopbackHost
  // ================================================================

  /// host がループバックアドレスかどうかを判定する（純粋関数）。
  ///
  /// simctl フォールバック判定に使用する。loopback かつ /screenshot 不達の
  /// 場合のみ simctl へフォールバックする。
  ///
  /// - Returns: true = loopback（"localhost" / "127.0.0.1" / "::1"）
  public static func isLoopbackHost(_ host: String) -> Bool {
    return host == "localhost" || host == "127.0.0.1" || host == "::1"
  }

  // ================================================================
  // 内部ユーティリティ
  // ================================================================

  /// 文字列を JSON 文字列リテラル（前後ダブルクオート付き・エスケープ済み）にする。
  static func jsonEscaped(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
      switch scalar {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      default:
        if scalar.value < 0x20 {
          // 制御文字は \uXXXX へ
          let hex = String(scalar.value, radix: 16)
          out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
        } else {
          out.unicodeScalars.append(scalar)
        }
      }
    }
    out += "\""
    return out
  }
}
