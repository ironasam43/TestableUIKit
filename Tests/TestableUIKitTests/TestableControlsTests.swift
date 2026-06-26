import XCTest
import SwiftUI
@testable import TestableUIKit

// MARK: - Binding を backing する参照ボックス

@available(iOS 15.0, macOS 13.0, *)
@MainActor
private final class Box<T> {
  var value: T
  init(_ value: T) { self.value = value }
  var binding: Binding<T> {
    Binding(get: { self.value }, set: { self.value = $0 })
  }
}

@available(iOS 15.0, macOS 13.0, *)
@MainActor
final class TestableControlsTests: XCTestCase {

  // MARK: - Toggle bridge: toggle / setProperty / describe 自動導出 round-trip

  func testToggleBridgeRoundTrip() async throws {
    let box = Box(false)
    let bridge = BindingTestable<Bool>(
      id: "test.bridge.toggle",
      valueKey: "isOn",
      binding: box.binding,
      toJSON: { .bool($0) },
      fromJSON: { v in guard case .bool(let b) = v else { throw TestError.invalidParameters }; return b },
      commands: ["toggle": { !$0 }]
    )

    // describe 自動導出（初期値）
    XCTAssertEqual(bridge.describedState["isOn"], .bool(false))

    // toggle コマンド
    let afterToggle = try await bridge.perform(commandName: "toggle", parameters: .null)
    XCTAssertEqual(afterToggle["isOn"], .bool(true))
    XCTAssertTrue(box.value, "binding 越しに backing 値も更新される")

    // setProperty で false に書き戻し
    let params = JSONValue.object(["key": .string("isOn"), "value": .bool(false)])
    let afterSet = try await bridge.perform(commandName: "setProperty", parameters: params)
    XCTAssertEqual(afterSet["isOn"], .bool(false))
    XCTAssertFalse(box.value)
  }

  // MARK: - Stepper bridge: increment / decrement

  func testStepperBridgeIncrementDecrement() async throws {
    let box = Box(0)
    let bridge = BindingTestable<Int>(
      id: "test.bridge.stepper",
      valueKey: "value",
      binding: box.binding,
      toJSON: { .int($0) },
      fromJSON: { v in guard case .int(let n) = v else { throw TestError.invalidParameters }; return n },
      commands: ["increment": { $0 + 1 }, "decrement": { $0 - 1 }]
    )

    let inc = try await bridge.perform(commandName: "increment", parameters: .null)
    XCTAssertEqual(inc["value"], .int(1))
    let inc2 = try await bridge.perform(commandName: "increment", parameters: .null)
    XCTAssertEqual(inc2["value"], .int(2))
    let dec = try await bridge.perform(commandName: "decrement", parameters: .null)
    XCTAssertEqual(dec["value"], .int(1))
    XCTAssertEqual(box.value, 1)
  }

  // MARK: - TextField bridge: setProperty で text 更新

  func testTextFieldBridgeSetProperty() async throws {
    let box = Box("")
    let bridge = BindingTestable<String>(
      id: "test.bridge.textField",
      valueKey: "text",
      binding: box.binding,
      toJSON: { .string($0) },
      fromJSON: { v in guard case .string(let s) = v else { throw TestError.invalidParameters }; return s }
    )

    let params = JSONValue.object(["key": .string("text"), "value": .string("hello")])
    let result = try await bridge.perform(commandName: "setProperty", parameters: params)
    XCTAssertEqual(result["text"], .string("hello"))
    XCTAssertEqual(box.value, "hello")
  }

  // MARK: - Button bridge: tap で action 副作用

  func testButtonBridgeTapAction() async throws {
    let box = Box(0)
    var tapped = 0
    let bridge = BindingTestable<Int>(
      id: "test.bridge.button",
      valueKey: "tapCount",
      binding: box.binding,
      toJSON: { .int($0) },
      fromJSON: { v in guard case .int(let n) = v else { throw TestError.invalidParameters }; return n },
      actions: ["tap": { box.value += 1; tapped += 1 }]
    )

    let result = try await bridge.perform(commandName: "tap", parameters: .null)
    XCTAssertEqual(result["tapCount"], .int(1))
    XCTAssertEqual(tapped, 1)
  }

  // MARK: - unknownCommand throw

  func testBridgeUnknownCommandThrows() async {
    let box = Box(false)
    let bridge = BindingTestable<Bool>(
      id: "test.bridge.unknown",
      valueKey: "isOn",
      binding: box.binding,
      toJSON: { .bool($0) },
      fromJSON: { v in guard case .bool(let b) = v else { throw TestError.invalidParameters }; return b }
    )
    do {
      _ = try await bridge.perform(commandName: "nope", parameters: .null)
      XCTFail("unknownCommand を期待")
    } catch TestError.unknownCommand {
      // OK
    } catch {
      XCTFail("unknownCommand を期待: \(error)")
    }
  }
}
