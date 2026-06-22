import XCTest
@testable import TestableUIKit

// MARK: - TestableServer bind ホスト・ポート指定テスト (Design D 下地)

@available(iOS 15.0, macOS 12.0, *)
final class TestableServerTests: XCTestCase {

  private var registry: TestableRegistry!

  override func setUp() {
    super.setUp()
    registry = TestableRegistry()
  }

  // ----------------------------------------------------------------
  // 既定値の後方互換確認
  // ----------------------------------------------------------------

  // 引数省略（既定）で init が throw しない
  func testDefaultInit_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 8888, registry: registry))
  }

  // 既定 host は "127.0.0.1"（ループバック限定）
  func testDefaultInit_hostIsLoopback() throws {
    let server = try TestableServer(port: 8888, registry: registry)
    XCTAssertEqual(server.host, "127.0.0.1", "既定 host はループバック 127.0.0.1")
  }

  // 既定 port は 8888
  func testDefaultInit_portIsEightEightEightEight() throws {
    let server = try TestableServer(port: 8888, registry: registry)
    XCTAssertEqual(server.port, 8888, "既定 port は 8888")
  }

  // ----------------------------------------------------------------
  // ホスト明示指定
  // ----------------------------------------------------------------

  // "0.0.0.0" 指定（LAN 公開）で init が throw しない
  func testLanPublicHost_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 8888, host: "0.0.0.0", registry: registry))
  }

  // "0.0.0.0" 指定で host プロパティが反映される
  func testLanPublicHost_hostIsZeroZeroZeroZero() throws {
    let server = try TestableServer(port: 8888, host: "0.0.0.0", registry: registry)
    XCTAssertEqual(server.host, "0.0.0.0", "LAN 公開ホスト 0.0.0.0 がプロパティに反映される")
  }

  // カスタムホスト文字列が host プロパティに反映される
  func testCustomHost_isReflected() throws {
    let server = try TestableServer(port: 8888, host: "192.168.1.100", registry: registry)
    XCTAssertEqual(server.host, "192.168.1.100", "カスタムホストがプロパティに反映される")
  }

  // ----------------------------------------------------------------
  // ポート明示指定
  // ----------------------------------------------------------------

  // カスタムポートが port プロパティに反映される
  func testCustomPort_isReflected() throws {
    let server = try TestableServer(port: 9999, registry: registry)
    XCTAssertEqual(server.port, 9999, "カスタムポートがプロパティに反映される")
  }

  // host と port を両方明示して init が throw しない
  func testCustomHostAndPort_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 9000, host: "0.0.0.0", registry: registry))
  }

  // host と port の両方が反映される
  func testCustomHostAndPort_bothReflected() throws {
    let server = try TestableServer(port: 9000, host: "0.0.0.0", registry: registry)
    XCTAssertEqual(server.host, "0.0.0.0", "カスタムホストが反映される")
    XCTAssertEqual(server.port, 9000, "カスタムポートが反映される")
  }

  // ----------------------------------------------------------------
  // 後方互換: registry 注入 API に host 引数を追加しても既存呼び出しが壊れない
  // ----------------------------------------------------------------

  // host 省略で従来と同じシグネチャが使える（後方互換確認）
  func testBackwardCompatibility_existingCallers() throws {
    // 既存の DemoApp / CLI の呼び出しパターン（host 引数なし）
    let server = try TestableServer(port: 8888, registry: registry)
    XCTAssertNotNil(server, "host 引数省略で既存シグネチャが動く")
    XCTAssertEqual(server.port, 8888)
    XCTAssertEqual(server.host, "127.0.0.1")
  }

  // ----------------------------------------------------------------
  // screenshotProvider 注入テスト（Step 4 追加）
  // ----------------------------------------------------------------

  // screenshotProvider なしで init が throw しない（後方互換）
  func testInit_withoutProvider_doesNotThrow() {
    XCTAssertNoThrow(try TestableServer(port: 8888, registry: registry),
                     "screenshotProvider 省略で既存シグネチャが動く")
  }

  // screenshotProvider を渡しても init が throw しない
  func testInit_withProvider_doesNotThrow() {
    let provider: TestableServer.ScreenshotProvider = { Data("fake-png".utf8) }
    XCTAssertNoThrow(try TestableServer(port: 8888, registry: registry, screenshotProvider: provider),
                     "screenshotProvider 指定で init が throw しない")
  }

  // GET /screenshot: provider なし → 503 エラー JSON
  func testGetScreenshot_withoutProvider_returns503() async throws {
    let testPort: UInt16 = 9875
    let server = try TestableServer(port: testPort, registry: registry)
    server.start()
    try await Task.sleep(nanoseconds: 200_000_000)

    let url = URL(string: "http://127.0.0.1:\(testPort)/screenshot")!
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResp = try XCTUnwrap(response as? HTTPURLResponse)
    XCTAssertEqual(httpResp.statusCode, 503, "provider 未設定時は 503 を返す")

    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    XCTAssertNotNil(json?["error"], "エラー JSON に 'error' キーが含まれる")
  }

  // GET /screenshot: stub provider → 200 + base64
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
    XCTAssertEqual(httpResp.statusCode, 200, "stub provider 指定時は 200 を返す")

    let json = try JSONDecoder().decode([String: String].self, from: data)
    XCTAssertEqual(json["format"], "png", "format フィールドが 'png'")
    XCTAssertEqual(json["image_base64"], fakeImageData.base64EncodedString(),
                   "provider が返した Data が base64 で返る")
  }
}
