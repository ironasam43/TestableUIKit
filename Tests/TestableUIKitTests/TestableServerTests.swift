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
}
