import Network
import Foundation

@available(iOS 15.0, macOS 12.0, *)
public final class TestableServer: @unchecked Sendable {
  /// スクリーンショット PNG データを返すクロージャ型。
  /// アプリ側（DemoApp 等）が注入することで、TestableServer は UIKit/window を知らなくて済む。
  public typealias ScreenshotProvider = @MainActor @Sendable () async throws -> Data

  private let listener: NWListener
  private let queue = DispatchQueue(label: "testable.server", qos: .userInitiated)
  public let port: UInt16
  /// bind ホスト。"127.0.0.1"（既定）= ループバックのみ / "0.0.0.0" = 全インターフェース（LAN 公開）
  public let host: String
  private let registry: TestableRegistry
  /// スクリーンショット取得クロージャ（nil = 未設定、GET /screenshot は 503 を返す）
  private let screenshotProvider: ScreenshotProvider?

  private static let headerSeparator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n

  /// - Parameters:
  ///   - port: 待ち受けポート（既定 8888）
  ///   - host: bind アドレス（既定 "127.0.0.1" = ループバック限定。"0.0.0.0" で LAN 公開可）
  ///   - registry: コンポーネントの登録・検索に使う Registry インスタンス。
  ///               アプリ側で生成した同一インスタンスを渡すことでシングルトンを廃止する。
  ///   - screenshotProvider: スクリーンショット PNG を返すクロージャ。省略（nil）で GET /screenshot は 503。
  ///                         アプリ側で key window キャプチャを実装して注入する（UIKit 依存を app 側に閉じる）。
  public init(port: UInt16 = 8888, host: String = "127.0.0.1", registry: TestableRegistry, screenshotProvider: ScreenshotProvider? = nil) throws {
    self.port = port
    self.host = host
    self.registry = registry
    self.screenshotProvider = screenshotProvider
    guard let nwPort = NWEndpoint.Port(rawValue: port) else {
      throw TestError.invalidParameters
    }
    let params = NWParameters.tcp
    if host == "0.0.0.0" {
      // 全インターフェース（LAN 公開）— ポートのみ指定し NWListener の既定挙動を使用
      self.listener = try NWListener(using: params, on: nwPort)
    } else {
      // 特定ホストに bind（既定: 127.0.0.1 ループバックのみ）
      // requiredLocalEndpoint で NW スタックが指定 IP のみで待受する
      let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
      params.requiredLocalEndpoint = endpoint
      self.listener = try NWListener(using: params)
    }
  }

  public func start() {
    let host = self.host
    let port = self.port
    listener.stateUpdateHandler = { state in
      if case .ready = state {
        print("✅ TestableServer listening on http://\(host):\(port)")
      } else if case .failed(let error) = state {
        print("❌ TestableServer failed: \(error)")
      }
    }

    let queue = self.queue
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else { return }
      connection.start(queue: queue)
      self.receive(from: connection)
    }

    listener.start(queue: queue)
  }

  private func receive(from connection: NWConnection) {
    receive(connection: connection, accumulated: Data())
  }

  /// NWConnection.receive は部分受信（HTTP ヘッダーとボディが別 TCP セグメントで届く）で
  /// 即コールバック発火するため、ヘッダー終端 `\r\n\r\n` 未到達、または
  /// Content-Length 分のボディ未到達なら再帰的に receive を呼んで完全なリクエストを蓄積する。
  private func receive(connection: NWConnection, accumulated: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
      guard let self else { connection.cancel(); return }

      if error != nil {
        connection.cancel()
        return
      }

      var buffer = accumulated
      if let data, !data.isEmpty {
        buffer.append(data)
      }

      // ヘッダー終端未到達なら継続受信
      guard let sepRange = buffer.range(of: Self.headerSeparator) else {
        if isComplete || buffer.count >= 65536 {
          connection.cancel()
          return
        }
        self.receive(connection: connection, accumulated: buffer)
        return
      }

      // Content-Length を解析してボディ完了判定
      let headerData = buffer[..<sepRange.lowerBound]
      let bodyData = buffer[sepRange.upperBound...]
      let headerText = String(data: headerData, encoding: .utf8) ?? ""
      let contentLength = Self.parseContentLength(from: headerText) ?? 0

      if bodyData.count < contentLength {
        if isComplete || buffer.count >= 65536 {
          connection.cancel()
          return
        }
        self.receive(connection: connection, accumulated: buffer)
        return
      }

      Task { @MainActor [weak self] in
        guard let self else { return }
        let response = await self.handle(buffer)
        connection.send(content: response, completion: .contentProcessed { _ in
          connection.cancel()
        })
      }
    }
  }

  /// HTTP ヘッダー文字列から Content-Length を取り出す（大文字小文字を区別しない）。
  private static func parseContentLength(from headers: String) -> Int? {
    for line in headers.components(separatedBy: "\r\n") {
      let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2 else { continue }
      let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
      if name == "content-length" {
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        return Int(value)
      }
    }
    return nil
  }

  @MainActor
  private func handle(_ data: Data) async -> Data {
    guard let sepRange = data.range(of: Self.headerSeparator) else {
      return httpResp(400, #"{"error":"malformed request"}"#)
    }

    let headerData = data[..<sepRange.lowerBound]
    let bodyData = data[sepRange.upperBound...]

    guard let headerText = String(data: headerData, encoding: .utf8) else {
      return httpResp(400, #"{"error":"encoding error"}"#)
    }

    let firstLine = headerText.components(separatedBy: "\r\n").first ?? ""

    if firstLine.contains("GET /ping") {
      return httpResp(200, #"{"status":"ok"}"#)
    }

    if firstLine.contains("GET /screenshot") {
      guard let provider = screenshotProvider else {
        return httpResp(503, #"{"error":"screenshotProvider not configured"}"#)
      }
      do {
        let imageData = try await provider()
        let base64 = imageData.base64EncodedString()
        return httpResp(200, #"{"image_base64":"\#(base64)","format":"png"}"#)
      } catch {
        return httpResp(500, #"{"error":"screenshot capture failed"}"#)
      }
    }

    if firstLine.contains("POST /perform") {
      do {
        let req = try JSONDecoder().decode(PerformRequest.self, from: Data(bodyData))

        guard let testable = await registry.find(id: req.testID) else {
          return httpResp(404, #"{"error":"component not found"}"#)
        }

        let result = try await testable.perform(commandName: req.commandName, parameters: req.parameters)
        let resultData = try JSONEncoder().encode(result)
        let resultBody = String(data: resultData, encoding: .utf8) ?? "{}"
        return httpResp(200, resultBody)
      } catch {
        return httpResp(500, #"{"error":"\#(error.localizedDescription)"}"#)
      }
    }

    return httpResp(404, #"{"error":"not found"}"#)
  }

  private func httpResp(_ code: Int, _ body: String) -> Data {
    let statusText = code == 200 ? "OK" : "Error"
    let headers = "HTTP/1.1 \(code) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
    return (headers + body).data(using: .utf8) ?? Data()
  }

  deinit {
    listener.cancel()
  }
}

public struct PerformRequest: Codable {
  public let testID: String
  public let commandName: String
  public let parameters: JSONValue

  public init(testID: String, commandName: String, parameters: JSONValue) {
    self.testID = testID
    self.commandName = commandName
    self.parameters = parameters
  }

  // Wire format specification
  // Explicit CodingKeys to stabilize JSON schema
  enum CodingKeys: String, CodingKey {
    case testID = "testID"
    case commandName = "commandName"
    case parameters = "parameters"
  }
}
