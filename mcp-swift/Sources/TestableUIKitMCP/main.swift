//
//  main.swift
//  TestableUIKitMCP
//
//  TestableUIKit MCP Server (Swift) — MCP wrapper for UI testing
//
//  Thinly wraps TestableUIKit's HTTP IPC (localhost:8888) as MCP tools,
//  enabling Claude to drive a running iOS UI and inspect describedState in a structured way.
//  Stateless HTTP relay only — does not import TestableUIKit's Swift types.
//
//  Exposed MCP tools (5):
//    ui_ping         — GET /ping            liveness check
//    ui_getState     — POST /perform getState  state retrieval
//    ui_perform      — POST /perform          command execution (tap/setProperty, etc.)
//    ui_screenshot   — GET /screenshot (primary) / simctl (loopback fallback)
//    ui_runScenario  — runs a declarative JSON scenario (multi-step + expect assertions) in order
//
//  Prerequisites:
//    DemoApp is running on a physical device/Simulator (listening on :8888).
//    Connection target can be overridden via TESTABLE_IPC_HOST / TESTABLE_IPC_PORT env vars.
//

import Foundation
import MCP
import TestableUIKitMCPCore

// ================================================================
// Resolve connection target (env vars → host/port)
// ================================================================

let (ipcHost, ipcPort) = IPCHelpers.resolveIPCHostPort(
  env: ProcessInfo.processInfo.environment
)
let ipcBase = IPCHelpers.buildBaseURL(host: ipcHost, port: ipcPort)

// ================================================================
// HTTP relay utilities (URLSession)
// ================================================================

enum IPCError: Error, CustomStringConvertible {
  case badURL(String)
  case httpStatus(Int, String)
  case transport(String)

  var description: String {
    switch self {
    case .badURL(let u): return "invalid URL: \(u)"
    case .httpStatus(let code, let body): return "HTTP \(code): \(body)"
    case .transport(let msg): return msg
    }
  }
}

/// Sends a GET request and returns the response body as a string.
func httpGET(_ urlString: String, timeout: TimeInterval = 10) async throws -> (Int, Data) {
  guard let url = URL(string: urlString) else { throw IPCError.badURL(urlString) }
  var req = URLRequest(url: url)
  req.httpMethod = "GET"
  req.timeoutInterval = timeout
  let (data, resp) = try await URLSession.shared.data(for: req)
  let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
  return (code, data)
}

/// Sends a POST request with a JSON body and returns the response body as a string.
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

/// Serializes an MCP Value to a JSON string (for perform parameters).
func jsonString(from value: Value) -> String? {
  guard let data = try? JSONEncoder().encode(value) else { return nil }
  return String(data: data, encoding: .utf8)
}

// ================================================================
// Tool implementations (thin stateless HTTP relay)
// ================================================================

/// GET /ping liveness check. Returns response JSON string.
func uiPing() async throws -> String {
  let (code, data) = try await httpGET("\(ipcBase)/ping", timeout: 5)
  guard code == 200 else { throw IPCError.httpStatus(code, bodyString(data)) }
  return bodyString(data)
}

/// POST /perform getState — retrieves component state.
func uiGetState(testID: String) async throws -> String {
  let payload = IPCHelpers.buildPerformPayload(testID: testID, commandName: "getState")
  let (code, data) = try await httpPOSTJSON("\(ipcBase)/perform", body: payload)
  guard code == 200 else { throw IPCError.httpStatus(code, bodyString(data)) }
  return bodyString(data)
}

/// POST /perform — executes a command on a component.
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

/// GET /screenshot (primary path). Falls back to simctl only when host is loopback.
/// Returns: (base64 PNG, mimeType)
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
        throw IPCError.transport("Failed to parse GET /screenshot response: \(bodyString(data))")
      }
      return (b64, "image/png")
    }
    throw IPCError.httpStatus(code, bodyString(data))
  } catch let err as IPCError {
    // Propagate HTTP status errors as-is (e.g. 503 when provider is not configured)
    if case .httpStatus = err { throw err }
    // Connection failure → simctl fallback (loopback only)
    return try screenshotViaSimctl()
  } catch {
    // URLSession connection failure, etc. → simctl fallback (loopback only)
    if !IPCHelpers.isLoopbackHost(ipcHost) {
      throw IPCError.transport(
        "Failed to connect to GET /screenshot (host=\(ipcHost)): \(error)\n"
          + "When connecting to a physical device, ensure DemoApp is running and GET /screenshot is enabled."
      )
    }
    return try screenshotViaSimctl()
  }
}

/// Simulator-only fallback: simctl io booted screenshot.
func screenshotViaSimctl() throws -> (base64: String, mimeType: String) {
  guard IPCHelpers.isLoopbackHost(ipcHost) else {
    throw IPCError.transport(
      "GET /screenshot unreachable and host is not loopback (host=\(ipcHost)); simctl fallback unavailable."
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
    throw IPCError.transport("simctl screenshot failed: \(bodyString(errData))")
  }
  guard let png = FileManager.default.contents(atPath: tmp) else {
    throw IPCError.transport("Failed to read simctl output file: \(tmp)")
  }
  return (png.base64EncodedString(), "image/png")
}

/// Executes a declarative JSON scenario (Scenario) from the beginning in order.
/// Matches each step's describedState against expect, then returns the aggregated
/// pass/fail ScenarioResult as a JSON string.
///
/// Even if a step fails (HTTP error, `{"error":...}` response, or decode failure),
/// the scenario continues without aborting; the failed step is recorded and execution proceeds to the next step.
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

/// Sends /perform, decodes the response, and evaluates asserts for a single step.
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
      return failure("/perform response is not an object: \(bodyString(data))")
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
// MCP server setup (tool registration / stdio transport)
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
      description: "Liveness check for the TestableUIKit server (GET /ping). Confirms DemoApp is running.",
      inputSchema: .object(["type": .string("object"), "properties": .object([:])])
    ),
    Tool(
      name: "ui_getState",
      description: "Retrieves the current describedState of the specified component (POST /perform getState).",
      inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
          "testID": .object([
            "type": .string("string"),
            "description": .string("testID of the component (e.g. scene.auth.loginButton)"),
          ])
        ]),
        "required": .array([.string("testID")]),
      ])
    ),
    Tool(
      name: "ui_perform",
      description: "Sends a command to a component (POST /perform). Supports tap / setProperty / setEnabled / increment, etc.",
      inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
          "testID": .object([
            "type": .string("string"),
            "description": .string("testID of the component"),
          ]),
          "command": .object([
            "type": .string("string"),
            "description": .string("Command name (tap / setProperty / setEnabled / increment, etc.)"),
          ]),
          "params": .object([
            "type": .string("object"),
            "description": .string("Command parameters (varies by command; optional)"),
          ]),
        ]),
        "required": .array([.string("testID"), .string("command")]),
      ])
    ),
    Tool(
      name: "ui_screenshot",
      description: "Captures a screenshot of the running DemoApp (physical device / Simulator) via GET /screenshot (primary) with simctl fallback.",
      inputSchema: .object(["type": .string("object"), "properties": .object([:])])
    ),
    Tool(
      name: "ui_runScenario",
      description:
        "Executes a declarative JSON scenario (a sequence of action/testID/parameters/expect steps) from the beginning in order, "
        + "then returns structured pass/fail results by matching each step's describedState against expect.",
      inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
          "scenario": .object([
            "type": .string("object"),
            "description": .string("Scenario definition object"),
            "properties": .object([
              "name": .object([
                "type": .string("string"),
                "description": .string("Scenario name"),
              ]),
              "steps": .object([
                "type": .string("array"),
                "description": .string("Array of steps to execute"),
                "items": .object([
                  "type": .string("object"),
                  "properties": .object([
                    "action": .object([
                      "type": .string("string"),
                      "enum": .array(ScenarioAction.known.map { .string($0) }),
                      "description": .string(
                        "Command to execute: getState / setProperty (universal) "
                        + "| tap / increment / decrement / reset / toggle / clear / setEnabled (component-specific)"),
                    ]),
                    "testID": .object([
                      "type": .string("string"),
                      "description": .string("testID of the target component"),
                    ]),
                    "parameters": .object([
                      "type": .string("object"),
                      "description": .string(
                        "Command parameters (optional). setProperty uses { \"key\": string, \"value\": any } format"),
                    ]),
                    "expect": .object([
                      "type": .string("object"),
                      "description": .string(
                        "Assert key/expected-value pairs after execution (optional). "
                        + "Fixed keys: isEnabled / title / isHidden / alpha / backgroundColor "
                        + "| Component-specific: count / isOn / label / value / text, etc."),
                    ]),
                  ]),
                  "required": .array([.string("action"), .string("testID")]),
                ]),
              ]),
            ]),
            "required": .array([.string("name"), .string("steps")]),
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
        return .init(content: [.text(text: "testID is required", annotations: nil, _meta: nil)], isError: true)
      }
      let json = try await uiGetState(testID: testID)
      return .init(content: [.text(text: json, annotations: nil, _meta: nil)], isError: false)

    case "ui_perform":
      guard let testID = params.arguments?["testID"]?.stringValue,
        let command = params.arguments?["command"]?.stringValue
      else {
        return .init(content: [.text(text: "testID and command are required", annotations: nil, _meta: nil)], isError: true)
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
        return .init(content: [.text(text: "scenario is required", annotations: nil, _meta: nil)], isError: true)
      }
      guard let scenarioJSON = jsonString(from: scenarioValue) else {
        return .init(
          content: [.text(text: "Failed to serialize scenario", annotations: nil, _meta: nil)],
          isError: true)
      }
      let resultJSON = try await uiRunScenario(scenarioJSON: scenarioJSON)
      return .init(content: [.text(text: resultJSON, annotations: nil, _meta: nil)], isError: false)

    default:
      return .init(content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)], isError: true)
    }
  } catch {
    return .init(content: [.text(text: "Error: \(error)", annotations: nil, _meta: nil)], isError: true)
  }
}

// --- Start with stdio transport and wait for completion ---
let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
