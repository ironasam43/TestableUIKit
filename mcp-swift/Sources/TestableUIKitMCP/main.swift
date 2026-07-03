//
//  main.swift
//  TestableUIKitMCP
//
//  TestableUIKit MCP Server（Swift 版） — UI テスト用 MCP ラッパー
//
//  TestableUIKit の HTTP IPC（localhost:8888）を MCP tool で薄くラップし、
//  Claude が実行中の iOS UI を直接駆動・describedState を構造化検査できる。
//  状態レス HTTP 中継のみで、TestableUIKit の Swift 型は import しない。
//
//  公開する MCP tool（5本）:
//    ui_ping         — GET /ping            死活確認
//    ui_getState     — POST /perform getState  状態取得
//    ui_perform      — POST /perform          コマンド実行（tap/setProperty など）
//    ui_screenshot   — GET /screenshot（一次）/ simctl（loopback フォールバック）
//    ui_runScenario  — 宣言的 JSON シナリオ（複数ステップ＋expect assert）を順に実行
//
//  前提:
//    DemoApp が iOS 実機 / Simulator 上で起動済み（:8888 でリッスン中）。
//    接続先は環境変数 TESTABLE_IPC_HOST / TESTABLE_IPC_PORT で上書き可。
//

import Foundation
import MCP
import TestableUIKitMCPCore

// ================================================================
// 接続先解決（環境変数 → host/port）
// ================================================================

let (ipcHost, ipcPort) = IPCHelpers.resolveIPCHostPort(
  env: ProcessInfo.processInfo.environment
)
let ipcBase = IPCHelpers.buildBaseURL(host: ipcHost, port: ipcPort)

// ================================================================
// HTTP 中継ユーティリティ（URLSession）
// ================================================================

enum IPCError: Error, CustomStringConvertible {
  case badURL(String)
  case httpStatus(Int, String)
  case transport(String)

  var description: String {
    switch self {
    case .badURL(let u): return "不正な URL: \(u)"
    case .httpStatus(let code, let body): return "HTTP \(code): \(body)"
    case .transport(let msg): return msg
    }
  }
}

/// GET リクエストを送りレスポンス本文（文字列）を返す。
func httpGET(_ urlString: String, timeout: TimeInterval = 10) async throws -> (Int, Data) {
  guard let url = URL(string: urlString) else { throw IPCError.badURL(urlString) }
  var req = URLRequest(url: url)
  req.httpMethod = "GET"
  req.timeoutInterval = timeout
  let (data, resp) = try await URLSession.shared.data(for: req)
  let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
  return (code, data)
}

/// POST リクエスト（JSON body）を送りレスポンス本文（文字列）を返す。
func httpPOSTJSON(_ urlString: String, body: String, timeout: TimeInterval = 10) async throws -> (Int, Data) {
  guard let url = URL(string: urlString) else { throw IPCError.badURL(urlString) }
  var req = URLRequest(url: url)
  req.httpMethod = "POST"
  req.timeoutInterval = timeout
  req.setValue("application/json", forHTTPHeaderField: "Content-Type")
  req.httpBody = body.data(using: .utf8)
  let (data, resp) = try await URLSession.shared.data(for: req)
  let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
  return (code, data)
}

func bodyString(_ data: Data) -> String {
  return String(data: data, encoding: .utf8) ?? ""
}

/// MCP の Value を JSON 文字列へシリアライズする（perform の parameters 用）。
func jsonString(from value: Value) -> String? {
  guard let data = try? JSONEncoder().encode(value) else { return nil }
  return String(data: data, encoding: .utf8)
}

// ================================================================
// ツール実体（HTTP を薄く中継・状態レス）
// ================================================================

/// GET /ping 死活確認。レスポンス JSON 文字列を返す。
func uiPing() async throws -> String {
  let (code, data) = try await httpGET("\(ipcBase)/ping", timeout: 5)
  guard code == 200 else { throw IPCError.httpStatus(code, bodyString(data)) }
  return bodyString(data)
}

/// POST /perform getState 状態取得。
func uiGetState(testID: String) async throws -> String {
  let payload = IPCHelpers.buildPerformPayload(testID: testID, commandName: "getState")
  let (code, data) = try await httpPOSTJSON("\(ipcBase)/perform", body: payload)
  guard code == 200 else { throw IPCError.httpStatus(code, bodyString(data)) }
  return bodyString(data)
}

/// POST /perform コマンド実行。
func uiPerform(testID: String, command: String, params: Value?) async throws -> String {
  let paramsJSON: String?
  if let params, params != .null {
    paramsJSON = jsonString(from: params)
  } else {
    paramsJSON = nil
  }
  let payload = IPCHelpers.buildPerformPayload(
    testID: testID, commandName: command, parametersJSON: paramsJSON
  )
  let (code, data) = try await httpPOSTJSON("\(ipcBase)/perform", body: payload)
  guard code == 200 else { throw IPCError.httpStatus(code, bodyString(data)) }
  return bodyString(data)
}

/// GET /screenshot（一次経路）。失敗時 loopback のみ simctl フォールバック。
/// 戻り値: (base64 PNG, mimeType)
func uiScreenshot() async throws -> (base64: String, mimeType: String) {
  let url = IPCHelpers.buildScreenshotURL(host: ipcHost, port: ipcPort)
  do {
    let (code, data) = try await httpGET(url, timeout: 10)
    if code == 200 {
      // {"image_base64":"...","format":"png"}
      guard
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let b64 = obj["image_base64"] as? String
      else {
        throw IPCError.transport("GET /screenshot のレスポンス解析に失敗: \(bodyString(data))")
      }
      return (b64, "image/png")
    }
    throw IPCError.httpStatus(code, bodyString(data))
  } catch let err as IPCError {
    // HTTP ステータス異常はそのまま伝播（provider 未設定 503 等）
    if case .httpStatus = err { throw err }
    // 接続失敗系 → loopback のみ simctl フォールバック
    return try screenshotViaSimctl()
  } catch {
    // URLSession の接続失敗など → loopback のみ simctl フォールバック
    if !IPCHelpers.isLoopbackHost(ipcHost) {
      throw IPCError.transport(
        "GET /screenshot への接続に失敗しました (host=\(ipcHost)): \(error)\n"
          + "実機接続時は DemoApp が起動中で GET /screenshot が有効か確認してください。"
      )
    }
    return try screenshotViaSimctl()
  }
}

/// Simulator 専用フォールバック: simctl io booted screenshot。
func screenshotViaSimctl() throws -> (base64: String, mimeType: String) {
  guard IPCHelpers.isLoopbackHost(ipcHost) else {
    throw IPCError.transport(
      "GET /screenshot 不達かつ非 loopback (host=\(ipcHost)) のため simctl フォールバック不可。"
    )
  }
  let tmp = NSTemporaryDirectory() + "testableui-shot-\(ProcessInfo.processInfo.processIdentifier).png"
  let cmd = IPCHelpers.buildSimctlScreenshotCommand(outputPath: tmp)
  let proc = Process()
  proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  proc.arguments = cmd
  let errPipe = Pipe()
  proc.standardError = errPipe
  try proc.run()
  proc.waitUntilExit()
  defer { try? FileManager.default.removeItem(atPath: tmp) }
  guard proc.terminationStatus == 0 else {
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    throw IPCError.transport("simctl screenshot 失敗: \(bodyString(errData))")
  }
  guard let png = FileManager.default.contents(atPath: tmp) else {
    throw IPCError.transport("simctl 出力ファイルの読み込みに失敗: \(tmp)")
  }
  return (png.base64EncodedString(), "image/png")
}

/// 宣言的 JSON シナリオ（Scenario）を先頭から順に実行し、各ステップの
/// describedState を expect と突合、pass/fail を集約した ScenarioResult を
/// JSON 文字列で返す。
///
/// ステップ実行が失敗（HTTP 異常・`{"error":...}` 応答・デコード失敗）しても
/// シナリオ全体は中断せず、当該ステップを fail として記録し次のステップへ進む。
func uiRunScenario(scenarioJSON: String) async throws -> String {
  let scenario = try ScenarioParser.parse(jsonString: scenarioJSON)
  var stepResults: [StepResult] = []

  for (index, step) in scenario.steps.enumerated() {
    let paramsJSON: String?
    if let params = step.parameters, params != .null {
      let data = try JSONEncoder().encode(params)
      paramsJSON = String(data: data, encoding: .utf8)
    } else {
      paramsJSON = nil
    }
    let payload = IPCHelpers.buildPerformPayload(
      testID: step.testID, commandName: step.action, parametersJSON: paramsJSON
    )

    stepResults.append(
      await runScenarioStep(index: index, step: step, payload: payload)
    )
  }

  let result = ScenarioEvaluator.buildScenarioResult(name: scenario.name, stepResults: stepResults)
  let data = try JSONEncoder().encode(result)
  return String(data: data, encoding: .utf8) ?? "{}"
}

/// 1 ステップぶんの /perform 送信・応答デコード・assert 評価をまとめて行う。
func runScenarioStep(index: Int, step: ScenarioStep, payload: String) async -> StepResult {
  func failure(_ message: String) -> StepResult {
    StepResult(
      index: index, action: step.action, testID: step.testID, success: false, error: message,
      describedState: nil, asserts: [], passed: false
    )
  }

  do {
    let (code, data) = try await httpPOSTJSON("\(ipcBase)/perform", body: payload)
    guard code == 200 else {
      return failure("HTTP \(code): \(bodyString(data))")
    }
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
    guard let obj = decoded.objectValue else {
      return failure("/perform 応答が object ではありません: \(bodyString(data))")
    }
    if case .string(let errMsg)? = obj["error"] {
      return failure(errMsg)
    }
    let asserts = step.expect.map { ScenarioEvaluator.evaluateExpect(expected: $0, actual: obj) } ?? []
    let passed = asserts.allSatisfy { $0.passed }
    return StepResult(
      index: index, action: step.action, testID: step.testID, success: true, error: nil,
      describedState: obj, asserts: asserts, passed: passed
    )
  } catch {
    return failure("\(error)")
  }
}

// ================================================================
// MCP サーバ構築（ツール登録・stdio transport）
// ================================================================

let server = Server(
  name: "TestableUIKit",
  version: "0.1.0"
)

// --- tools/list ---
await server.withMethodHandler(ListTools.self) { _ in
  let tools = [
    Tool(
      name: "ui_ping",
      description: "TestableUIKit サーバーの死活確認（GET /ping）。DemoApp が起動中か確認する。",
      inputSchema: .object(["type": .string("object"), "properties": .object([:])])
    ),
    Tool(
      name: "ui_getState",
      description: "指定コンポーネントの現在の describedState を取得する（POST /perform getState）。",
      inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
          "testID": .object([
            "type": .string("string"),
            "description": .string("コンポーネントの testID（例: scene.auth.loginButton）"),
          ])
        ]),
        "required": .array([.string("testID")]),
      ])
    ),
    Tool(
      name: "ui_perform",
      description: "コンポーネントにコマンドを送信する（POST /perform）。tap / setProperty / setEnabled / increment など。",
      inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
          "testID": .object([
            "type": .string("string"),
            "description": .string("コンポーネントの testID"),
          ]),
          "command": .object([
            "type": .string("string"),
            "description": .string("コマンド名（tap / setProperty / setEnabled / increment など）"),
          ]),
          "params": .object([
            "type": .string("object"),
            "description": .string("コマンドパラメータ（コマンドにより異なる。省略可）"),
          ]),
        ]),
        "required": .array([.string("testID"), .string("command")]),
      ])
    ),
    Tool(
      name: "ui_screenshot",
      description: "起動中の DemoApp（実機 / Simulator）のスクリーンショットを取得する（GET /screenshot 一次・simctl フォールバック）。",
      inputSchema: .object(["type": .string("object"), "properties": .object([:])])
    ),
    Tool(
      name: "ui_runScenario",
      description:
        "宣言的 JSON シナリオ（複数ステップの action/testID/parameters/expect 列）を先頭から順に実行し、"
        + "各ステップの describedState を expect と突合した pass/fail 結果を構造化して返す。",
      inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
          "scenario": .object([
            "type": .string("object"),
            "description": .string(
              "{ name: string, steps: [{ action, testID, parameters?, expect? }] } 形式のシナリオ"),
          ])
        ]),
        "required": .array([.string("scenario")]),
      ])
    ),
  ]
  return .init(tools: tools)
}

// --- tools/call ---
await server.withMethodHandler(CallTool.self) { params in
  do {
    switch params.name {
    case "ui_ping":
      let json = try await uiPing()
      return .init(content: [.text(text: json, annotations: nil, _meta: nil)], isError: false)

    case "ui_getState":
      guard let testID = params.arguments?["testID"]?.stringValue else {
        return .init(content: [.text(text: "testID は必須です", annotations: nil, _meta: nil)], isError: true)
      }
      let json = try await uiGetState(testID: testID)
      return .init(content: [.text(text: json, annotations: nil, _meta: nil)], isError: false)

    case "ui_perform":
      guard let testID = params.arguments?["testID"]?.stringValue,
        let command = params.arguments?["command"]?.stringValue
      else {
        return .init(content: [.text(text: "testID と command は必須です", annotations: nil, _meta: nil)], isError: true)
      }
      let json = try await uiPerform(
        testID: testID, command: command, params: params.arguments?["params"]
      )
      return .init(content: [.text(text: json, annotations: nil, _meta: nil)], isError: false)

    case "ui_screenshot":
      let (b64, mime) = try await uiScreenshot()
      return .init(content: [.image(data: b64, mimeType: mime, annotations: nil, _meta: nil)], isError: false)

    case "ui_runScenario":
      guard let scenarioValue = params.arguments?["scenario"] else {
        return .init(content: [.text(text: "scenario は必須です", annotations: nil, _meta: nil)], isError: true)
      }
      guard let scenarioJSON = jsonString(from: scenarioValue) else {
        return .init(
          content: [.text(text: "scenario のシリアライズに失敗しました", annotations: nil, _meta: nil)],
          isError: true)
      }
      let resultJSON = try await uiRunScenario(scenarioJSON: scenarioJSON)
      return .init(content: [.text(text: resultJSON, annotations: nil, _meta: nil)], isError: false)

    default:
      return .init(content: [.text(text: "未知のツール: \(params.name)", annotations: nil, _meta: nil)], isError: true)
    }
  } catch {
    return .init(content: [.text(text: "エラー: \(error)", annotations: nil, _meta: nil)], isError: true)
  }
}

// --- stdio transport で起動し完了まで待機 ---
let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
