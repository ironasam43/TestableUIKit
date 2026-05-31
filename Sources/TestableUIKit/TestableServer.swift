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
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
      guard let self else { connection.cancel(); return }

      if error != nil {
        connection.cancel()
        return
      }

      guard let data else {
        connection.cancel()
        return
      }

      Task { @MainActor [weak self] in
        guard let self else { return }
        let response = await self.handle(data)
        connection.send(content: response, completion: .contentProcessed { _ in
          connection.cancel()
        })
      }
    }
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
