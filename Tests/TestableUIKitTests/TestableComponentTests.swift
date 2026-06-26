import XCTest
@testable import TestableUIKit

// MARK: - テスト用 state 値型

private struct ToggleState {
  var isOn: Bool = false
}

private struct MultiState {
  var count: Int = 0
  var ratio: Double = 0.0
  var label: String = "init"
  var flag: Bool = false
}

@MainActor
final class TestableComponentTests: XCTestCase {

  // MARK: - properties 経由の getState → setProperty → getState round-trip

  func testGetSetGetRoundTrip() async throws {
    let component = TestableComponent<ToggleState>(
      id: "test.component.toggle",
      state: ToggleState(),
      properties: ["isOn": .bool(\.isOn)],
      commands: ["toggle": { state, _ in state.isOn.toggle() }]
    )

    // getState（初期値）
    let initial = try await component.perform(commandName: "getState", parameters: .null)
    XCTAssertEqual(initial["isOn"], .bool(false))

    // setProperty で isOn を true に
    let params = JSONValue.object(["key": .string("isOn"), "value": .bool(true)])
    let afterSet = try await component.perform(commandName: "setProperty", parameters: params)
    XCTAssertEqual(afterSet["isOn"], .bool(true))

    // getState で反映を確認
    let afterGet = try await component.perform(commandName: "getState", parameters: .null)
    XCTAssertEqual(afterGet["isOn"], .bool(true))
  }

  // MARK: - toggle コマンド

  func testToggleCommand() async throws {
    let component = TestableComponent<ToggleState>(
      id: "test.component.toggle2",
      state: ToggleState(),
      properties: ["isOn": .bool(\.isOn)],
      commands: ["toggle": { state, _ in state.isOn.toggle() }]
    )

    let r1 = try await component.perform(commandName: "toggle", parameters: .null)
    XCTAssertEqual(r1["isOn"], .bool(true))
    let r2 = try await component.perform(commandName: "toggle", parameters: .null)
    XCTAssertEqual(r2["isOn"], .bool(false))
  }

  // MARK: - Mirror フォールバック describe（properties / describe 省略）

  func testMirrorFallbackDescribe() async throws {
    let component = TestableComponent<MultiState>(
      id: "test.component.mirror",
      state: MultiState(count: 3, ratio: 1.5, label: "hello", flag: true)
    )

    let described = component.describedState
    XCTAssertEqual(described["count"], .int(3))
    XCTAssertEqual(described["ratio"], .double(1.5))
    XCTAssertEqual(described["label"], .string("hello"))
    XCTAssertEqual(described["flag"], .bool(true))

    // getState 経由でも同一
    let viaGet = try await component.perform(commandName: "getState", parameters: .null)
    XCTAssertEqual(viaGet["count"], .int(3))
    XCTAssertEqual(viaGet["label"], .string("hello"))
  }

  // MARK: - describe override 優先

  func testDescribeOverridePriority() {
    let component = TestableComponent<MultiState>(
      id: "test.component.override",
      state: MultiState(count: 9, label: "ignored"),
      describe: { _ in ["custom": .string("fixed")] },
      properties: ["count": .int(\.count)]
    )
    // describe override が properties / Mirror より優先される
    XCTAssertEqual(component.describedState, ["custom": .string("fixed")])
  }

  // MARK: - unknownCommand throw

  func testUnknownCommandThrows() async {
    let component = TestableComponent<ToggleState>(
      id: "test.component.unknown",
      state: ToggleState(),
      properties: ["isOn": .bool(\.isOn)]
    )
    do {
      _ = try await component.perform(commandName: "nope", parameters: .null)
      XCTFail("unknownCommand を期待")
    } catch TestError.unknownCommand {
      // OK
    } catch {
      XCTFail("unknownCommand を期待: \(error)")
    }
  }

  // MARK: - setProperty 未知キー → unknownCommand

  func testSetPropertyUnknownKeyThrows() async {
    let component = TestableComponent<ToggleState>(
      id: "test.component.unknownkey",
      state: ToggleState(),
      properties: ["isOn": .bool(\.isOn)]
    )
    let params = JSONValue.object(["key": .string("missing"), "value": .bool(true)])
    do {
      _ = try await component.perform(commandName: "setProperty", parameters: params)
      XCTFail("unknownCommand を期待")
    } catch TestError.unknownCommand {
      // OK
    } catch {
      XCTFail("unknownCommand を期待: \(error)")
    }
  }

  // MARK: - setProperty 型不一致 → invalidParameters

  func testSetPropertyWrongTypeThrows() async {
    let component = TestableComponent<ToggleState>(
      id: "test.component.wrongtype",
      state: ToggleState(),
      properties: ["isOn": .bool(\.isOn)]
    )
    let params = JSONValue.object(["key": .string("isOn"), "value": .string("true")])
    do {
      _ = try await component.perform(commandName: "setProperty", parameters: params)
      XCTFail("invalidParameters を期待")
    } catch TestError.invalidParameters {
      // OK
    } catch {
      XCTFail("invalidParameters を期待: \(error)")
    }
  }

  // MARK: - TestableProperty.double は int も受理する

  func testDoublePropertyAcceptsInt() async throws {
    let component = TestableComponent<MultiState>(
      id: "test.component.double",
      state: MultiState(),
      properties: ["ratio": .double(\.ratio)]
    )
    let params = JSONValue.object(["key": .string("ratio"), "value": .int(2)])
    let result = try await component.perform(commandName: "setProperty", parameters: params)
    XCTAssertEqual(result["ratio"], .double(2.0))
  }
}
