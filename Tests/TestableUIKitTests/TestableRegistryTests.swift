import XCTest
@testable import TestableUIKit

// MARK: - テスト用最小 AnyTestable 実装

private final class MockTestable: AnyTestable, @unchecked Sendable {
  let testID: String

  init(testID: String) {
    self.testID = testID
  }

  var describedState: [String: JSONValue] { ["stub": .bool(true)] }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    return describedState
  }
}

// MARK: - TestableRegistry Tests

final class TestableRegistryTests: XCTestCase {

  // register → find round-trip: 登録した testable が testID で取得できる
  func testRegisterAndFind() async throws {
    let id = "test.registry.roundtrip"
    let mock = MockTestable(testID: id)

    await TestableRegistry.shared.register(mock)
    let found = await TestableRegistry.shared.find(id: id)

    XCTAssertNotNil(found, "登録済み testable は find で取得できる")
    XCTAssertEqual(found?.testID, id, "取得した testable の testID が一致する")
  }

  // 未登録 ID は nil を返す
  func testFindUnregisteredReturnsNil() async throws {
    let id = "test.registry.nonexistent.\(UUID().uuidString)"
    let found = await TestableRegistry.shared.find(id: id)

    XCTAssertNil(found, "未登録の testID は nil を返す")
  }

  // 同じ ID で再登録すると新しいインスタンスで上書きされる
  func testReregisterOverwrites() async throws {
    let id = "test.registry.overwrite"
    let first = MockTestable(testID: id)
    let second = MockTestable(testID: id)

    await TestableRegistry.shared.register(first)
    await TestableRegistry.shared.register(second)
    let found = await TestableRegistry.shared.find(id: id)

    XCTAssertNotNil(found, "再登録後も find で取得できる")
    XCTAssertTrue(found === second, "再登録で新しいインスタンスに上書きされる")
  }

  // describedState が取得できる（AnyTestable 契約の基本確認）
  func testDescribedState() async throws {
    let id = "test.registry.state"
    let mock = MockTestable(testID: id)

    await TestableRegistry.shared.register(mock)
    let found = await TestableRegistry.shared.find(id: id)

    XCTAssertEqual(found?.describedState["stub"], .bool(true), "describedState が期待値どおり")
  }
}
