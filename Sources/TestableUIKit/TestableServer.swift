import Network
import Foundation

@available(iOS 15.0, macOS 12.0, *)
public final class TestableServer: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "testable.server", qos: .userInitiated)
  public let port: UInt16

  private static let headerSeparator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n

  public init(port: UInt16 = 8888) throws {
    self.port = port
    guard let nwPort = NWEndpoint.Port(rawValue: port) else {
      throw TestError.invalidParameters
    }
    self.listener = try NWListener(using: .tcp, on: nwPort)
  }

  public func start() {
    listener.stateUpdateHandler = { state in
      if case .ready = state {
        print("✅ TestableServer listening on http://localhost:8888")
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

    if firstLine.contains("POST /perform") {
      do {
        let req = try JSONDecoder().decode(PerformRequest.self, from: Data(bodyData))

        guard let testable = await TestableRegistry.shared.find(id: req.testID) else {
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
