import XCTest
@testable import TestableUIKit

// MARK: - TestableServer bind host/port tests (Design D groundwork)

@available(iOS 15.0, macOS 12.0, *)
final class TestableServerTests: XCTestCase {

  private var registry: TestableRegistry!

  override func setUp() {
    super.setUp()
    registry = TestableRegistry()
  }

  // ----------------------------------------------------------------
  // Default value backward-compatibility
  // ----------------------------------------------------------------

  // init with defaults (no arguments) must not throw
  func testDefaultInit_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 8888, registry: registry))
  }

  // Default host is "127.0.0.1" (loopback only)
  func testDefaultInit_hostIsLoopback() throws {
    let server = try TestableServer(port: 8888, registry: registry)
    XCTAssertEqual(server.host, "127.0.0.1", "Default host should be loopback 127.0.0.1")
  }

  // Default port is 8888
  func testDefaultInit_portIsEightEightEightEight() throws {
    let server = try TestableServer(port: 8888, registry: registry)
    XCTAssertEqual(server.port, 8888, "Default port should be 8888")
  }

  // ----------------------------------------------------------------
  // Explicit host
  // ----------------------------------------------------------------

  // "0.0.0.0" (LAN public) must not throw
  func testLanPublicHost_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 8888, host: "0.0.0.0", registry: registry))
  }

  // "0.0.0.0" must be reflected in the host property
  func testLanPublicHost_hostIsZeroZeroZeroZero() throws {
    let server = try TestableServer(port: 8888, host: "0.0.0.0", registry: registry)
    XCTAssertEqual(server.host, "0.0.0.0", "LAN public host 0.0.0.0 must be reflected in the property")
  }

  // Custom host string must be reflected in the host property
  func testCustomHost_isReflected() throws {
    let server = try TestableServer(port: 8888, host: "192.168.1.100", registry: registry)
    XCTAssertEqual(server.host, "192.168.1.100", "Custom host must be reflected in the property")
  }

  // ----------------------------------------------------------------
  // Explicit port
  // ----------------------------------------------------------------

  // Custom port must be reflected in the port property
  func testCustomPort_isReflected() throws {
    let server = try TestableServer(port: 9999, registry: registry)
    XCTAssertEqual(server.port, 9999, "Custom port must be reflected in the property")
  }

  // Specifying both host and port must not throw
  func testCustomHostAndPort_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 9000, host: "0.0.0.0", registry: registry))
  }

  // Both host and port must be reflected in their properties
  func testCustomHostAndPort_bothReflected() throws {
    let server = try TestableServer(port: 9000, host: "0.0.0.0", registry: registry)
    XCTAssertEqual(server.host, "0.0.0.0", "Custom host must be reflected")
    XCTAssertEqual(server.port, 9000, "Custom port must be reflected")
  }

  // ----------------------------------------------------------------
  // Backward compatibility: adding host argument must not break existing callers
  // ----------------------------------------------------------------

  // Omitting host must use the same signature as before (backward compatibility check)
  func testBackwardCompatibility_existingCallers() throws {
    // Calling pattern used by existing DemoApp / CLI (no host argument)
    let server = try TestableServer(port: 8888, registry: registry)
    XCTAssertNotNil(server, "Omitting host argument must work with the existing signature")
    XCTAssertEqual(server.port, 8888)
    XCTAssertEqual(server.host, "127.0.0.1")
  }

  // ----------------------------------------------------------------
  // screenshotProvider injection tests (Step 4 addition)
  // ----------------------------------------------------------------

  // init without screenshotProvider must not throw (backward compatibility)
  func testInit_withoutProvider_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 8888, registry: registry),
                     "Omitting screenshotProvider must work with the existing signature")
  }

  // init with screenshotProvider must not throw
  func testInit_withProvider_doesNotThrow() {
    let provider: TestableServer.ScreenshotProvider = { Data("fake-png".utf8) }
    XCTAssertNoThrow(try TestableServer(port: 8888, registry: registry, screenshotProvider: provider),
                     "Specifying screenshotProvider must not cause init to throw")
  }

  // GET /screenshot without provider → 503 error JSON
  func testGetScreenshot_withoutProvider_returns503() async throws {
    let testPort: UInt16 = 9875
    let server = try TestableServer(port: testPort, registry: registry)
    server.start()
    try await Task.sleep(nanoseconds: 200_000_000)

    let url = URL(string: "http://127.0.0.1:\(testPort)/screenshot")!
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResp = try XCTUnwrap(response as? HTTPURLResponse)
    XCTAssertEqual(httpResp.statusCode, 503, "Must return 503 when provider is not configured")

    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    XCTAssertNotNil(json?["error"], "Error JSON must contain an 'error' key")
  }

  // GET /screenshot with stub provider → 200 + base64
  func testGetScreenshot_withStubProvider_returnsBase64() async throws {
    let testPort: UInt16 = 9876
    let fakeImageData = Data("fake-png-data-for-test".utf8)
    let provider: TestableServer.ScreenshotProvider = { fakeImageData }

    let server = try TestableServer(port: testPort, registry: registry, screenshotProvider: provider)
    server.start()
    try await Task.sleep(nanoseconds: 200_000_000)

    let url = URL(string: "http://127.0.0.1:\(testPort)/screenshot")!
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResp = try XCTUnwrap(response as? HTTPURLResponse)
    XCTAssertEqual(httpResp.statusCode, 200, "Must return 200 when stub provider is configured")

    let json = try JSONDecoder().decode([String: String].self, from: data)
    XCTAssertEqual(json["format"], "png", "format field must be 'png'")
    XCTAssertEqual(json["image_base64"], fakeImageData.base64EncodedString(),
                   "The Data returned by the provider must come back as base64")
  }

  // ----------------------------------------------------------------
  // Graceful shutdown (stop) / port conflict detection (STEP 3 addition)
  // ----------------------------------------------------------------

  // start → ready state must arrive via onStateChange
  func testStart_emitsReadyState() throws {
    let testPort: UInt16 = 9801
    let server = try TestableServer(port: testPort, registry: registry)
    let readyExp = expectation(description: "ready state received")
    server.onStateChange = { state in
      if state == .ready { readyExp.fulfill() }
    }
    server.start()
    wait(for: [readyExp], timeout: 2.0)
    server.stop()
  }

  // stop() must trigger graceful shutdown and deliver .cancelled
  func testStop_emitsCancelledState() throws {
    let testPort: UInt16 = 9802
    let server = try TestableServer(port: testPort, registry: registry)
    let readyExp = expectation(description: "ready")
    let cancelledExp = expectation(description: "cancelled")
    server.onStateChange = { state in
      switch state {
      case .ready: readyExp.fulfill()
      case .cancelled: cancelledExp.fulfill()
      default: break
      }
    }
    server.start()
    wait(for: [readyExp], timeout: 2.0)
    server.stop()
    wait(for: [cancelledExp], timeout: 2.0)
  }

  // Multiple stop() calls must not crash (idempotent)
  func testStop_isIdempotent() throws {
    let testPort: UInt16 = 9803
    let server = try TestableServer(port: testPort, registry: registry)
    let readyExp = expectation(description: "ready")
    server.onStateChange = { state in
      if state == .ready { readyExp.fulfill() }
    }
    server.start()
    wait(for: [readyExp], timeout: 2.0)
    server.stop()
    server.stop()
    server.stop()
  }

  // A second server on the same port must receive .failed (port conflict behavior)
  func testPortConflict_emitsFailedState() throws {
    let testPort: UInt16 = 9804
    let serverA = try TestableServer(port: testPort, registry: registry)
    let aReady = expectation(description: "A ready")
    serverA.onStateChange = { state in
      if state == .ready { aReady.fulfill() }
    }
    serverA.start()
    wait(for: [aReady], timeout: 2.0)

    let serverB = try TestableServer(port: testPort, registry: TestableRegistry())
    let bFailed = expectation(description: "B failed (port in use)")
    serverB.onStateChange = { state in
      if case .failed = state { bFailed.fulfill() }
    }
    serverB.start()
    wait(for: [bFailed], timeout: 3.0)

    serverB.stop()
    serverA.stop()
  }
}
