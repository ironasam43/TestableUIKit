//
//  IPCHelpers.swift
//  TestableUIKitMCPCore
//
//  TestableUIKit MCP Server — pure helper functions (Swift)
//
//  HTTP IPC URL construction, connection resolution, perform payload building,
//  simctl command generation, loopback detection. No external SwiftPM dependencies
//  (Foundation only). Unit-testable without Simulator / DemoApp / HTTP connection.
//
//  Port of mcp_server/ipc_helpers.py (Python). Behavior is matched 1:1.
//

import Foundation

public enum IPCHelpers {

  // ================================================================
  // Constants
  // ================================================================

  /// Default IPC host.
  public static let defaultIPCHost = "localhost"
  /// Default IPC port.
  public static let defaultIPCPort = 8888

  /// Environment variable name for overriding the IPC host (Design D: LAN IPC).
  public static let envIPCHost = "TESTABLE_IPC_HOST"
  /// Environment variable name for overriding the IPC port.
  public static let envIPCPort = "TESTABLE_IPC_PORT"

  // ================================================================
  // resolveIPCHostPort
  // ================================================================

  /// Resolves IPC host and port from environment variables.
  ///
  /// Returns default values (localhost:8888) when the variables are not set.
  /// Falls back to the default port when the port string cannot be parsed as an integer.
  ///
  /// - Parameter env: Environment variable dictionary to read (inject in tests).
  /// - Returns: A (host, port) tuple.
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

  /// Builds the IPC server base URL (no trailing slash).
  public static func buildBaseURL(
    host: String = defaultIPCHost,
    port: Int = defaultIPCPort
  ) -> String {
    return "http://\(host):\(port)"
  }

  // ================================================================
  // buildScreenshotURL
  // ================================================================

  /// Builds the URL for the GET /screenshot endpoint.
  public static func buildScreenshotURL(
    host: String = defaultIPCHost,
    port: Int = defaultIPCPort
  ) -> String {
    return "\(buildBaseURL(host: host, port: port))/screenshot"
  }

  // ================================================================
  // buildPerformPayload
  // ================================================================

  /// Builds the POST /perform request body as a JSON string.
  ///
  /// Key order is fixed: testID → commandName → parameters (deterministic).
  /// The caller passes parameters as an already-serialized JSON string.
  /// When nil, the JSON `null` literal is embedded.
  ///
  /// - Parameters:
  ///   - testID: Component testID (e.g. "scene.auth.loginButton").
  ///   - commandName: Command name (e.g. "getState" / "tap" / "setProperty").
  ///   - parametersJSON: Pre-serialized parameters JSON (defaults to null).
  /// - Returns: JSON string of the form `{"testID":...,"commandName":...,"parameters":...}`.
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

  /// Builds the `simctl io booted screenshot` command arguments (Simulator only).
  ///
  /// - Parameter outputPath: File path where the screenshot will be saved.
  /// - Returns: Argument list suitable for Process / subprocess.
  public static func buildSimctlScreenshotCommand(outputPath: String) -> [String] {
    return ["xcrun", "simctl", "io", "booted", "screenshot", outputPath]
  }

  // ================================================================
  // isLoopbackHost
  // ================================================================

  /// Returns whether the host is a loopback address (pure function).
  ///
  /// Used for simctl fallback decisions: falls back to simctl only when
  /// the host is loopback and the /screenshot endpoint is unreachable.
  ///
  /// - Returns: true = loopback ("localhost" / "127.0.0.1" / "::1").
  public static func isLoopbackHost(_ host: String) -> Bool {
    return host == "localhost" || host == "127.0.0.1" || host == "::1"
  }

  // ================================================================
  // Internal utilities
  // ================================================================

  /// Returns the string as a JSON string literal (double-quoted, escaped).
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
          // Control chars → \uXXXX
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
