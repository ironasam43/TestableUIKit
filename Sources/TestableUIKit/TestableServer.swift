import Network
import Foundation

@available(iOS 15.0, macOS 12.0, *)
public final class TestableServer: @unchecked Sendable {
  /// Closure type that returns screenshot PNG data.
  /// Injected by the app side (DemoApp, etc.) so that TestableServer does not need to know UIKit/window.
  public typealias ScreenshotProvider = @MainActor @Sendable () async throws -> Data

  /// Server listening state. Notified to outside via `onStateChange`.
  /// Startup failures such as port conflicts (EADDRINUSE) arrive as `.failed`.
  public enum State: Sendable, Equatable {
    case setup            // Initial state (before start)
    case ready            // Listening started; accepting connections
    case failed(String)   // Startup failed (port conflict, etc.). String is error description
    case cancelled        // Graceful shutdown completed via stop()
  }

  private let listener: NWListener
  private let queue = DispatchQueue(label: "testable.server", qos: .userInitiated)
  public let port: UInt16
  /// Bind host. "127.0.0.1" (default) = loopback only / "0.0.0.0" = all interfaces (LAN exposure)
  public let host: String
  private let registry: TestableRegistry
  /// Screenshot retrieval closure (nil = not configured; GET /screenshot returns 503)
  private let screenshotProvider: ScreenshotProvider?

  /// Handler that notifies external callers of listener state changes.
  /// On port 8888 conflict, `.failed` is delivered, allowing the caller to implement
  /// fallback to another port or user notification (previously only print; not programmatically detectable).
  public var onStateChange: (@Sendable (State) -> Void)?

  /// Currently listening connections. Only touched on queue for bulk cancellation via stop().
  private var connections: [NWConnection] = []

  private static let headerSeparator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n

  /// - Parameters:
  ///   - port: Listening port (default 8888)
  ///   - host: Bind address (default "127.0.0.1" = loopback only; "0.0.0.0" enables LAN exposure)
  ///   - registry: Registry instance used for component registration and lookup.
  ///               Pass the same instance created on the app side to eliminate singletons.
  ///   - screenshotProvider: Closure that returns screenshot PNG. Omitting (nil) makes GET /screenshot return 503.
  ///                         Implement key window capture on the app side and inject it (keeps UIKit dependency in the app).
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
      // All interfaces (LAN exposure) — specify port only, use NWListener default behavior
      self.listener = try NWListener(using: params, on: nwPort)
    } else {
      // Bind to specific host (default: 127.0.0.1 loopback only)
      // requiredLocalEndpoint makes the NW stack listen only on the specified IP
      let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
      params.requiredLocalEndpoint = endpoint
      self.listener = try NWListener(using: params)
    }
  }

  public func start() {
    let host = self.host
    let port = self.port
    listener.stateUpdateHandler = { [weak self] state in
      switch state {
      case .ready:
        print("✅ TestableServer listening on http://\(host):\(port)")
        self?.onStateChange?(.ready)
      case .failed(let error):
        // Port conflict (EADDRINUSE), etc. Previously only print; not programmatically detectable.
        print("❌ TestableServer failed on \(host):\(port): \(error)")
        self?.onStateChange?(.failed("\(error)"))
      case .cancelled:
        self?.onStateChange?(.cancelled)
      default:
        break
      }
    }

    let queue = self.queue
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else { return }
      // Track connections and remove them on completion/failure (for bulk cancellation via stop()).
      connection.stateUpdateHandler = { [weak self] cState in
        switch cState {
        case .cancelled, .failed:
          self?.queue.async { self?.connections.removeAll { $0 === connection } }
        default:
          break
        }
      }
      self.queue.async { self.connections.append(connection) }
      connection.start(queue: queue)
      self.receive(from: connection)
    }

    listener.start(queue: queue)
  }

  /// Graceful shutdown. Cancels all active connections and the listener to release the port.
  /// Completion is notified via `onStateChange(.cancelled)`. Safe to call multiple times (idempotent).
  public func stop() {
    queue.async { [weak self] in
      guard let self else { return }
      self.connections.forEach { $0.cancel() }
      self.connections.removeAll()
      self.listener.cancel()
    }
  }

  private func receive(from connection: NWConnection) {
    receive(connection: connection, accumulated: Data())
  }

  /// NWConnection.receive fires immediately on partial reception (HTTP headers and body may arrive in separate TCP segments).
  /// If the header terminator `\r\n\r\n` has not been reached, or the body per Content-Length is incomplete,
  /// this calls receive recursively to accumulate the full request.
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

      // Header terminator not yet reached; continue receiving
      guard let sepRange = buffer.range(of: Self.headerSeparator) else {
        if isComplete || buffer.count >= 65536 {
          connection.cancel()
          return
        }
        self.receive(connection: connection, accumulated: buffer)
        return
      }

      // Parse Content-Length and check if body is complete
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

  /// Extracts Content-Length from an HTTP header string (case-insensitive).
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
