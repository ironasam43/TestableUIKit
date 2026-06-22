import XCTest
import TestableUIKit

final class TextInputCoreTests: XCTestCase {
  private var state: TextInputState!

  override func setUp() {
    super.setUp()
    state = TextInputState()
  }

  override func tearDown() {
    state = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertEqual(state.text, "")
    XCTAssertEqual(state.placeholder, "Enter text")
    XCTAssertTrue(state.isEnabled)
  }

  func testDescribedStateInitial() {
    let described = makeTextInputDescribedState(state)
    XCTAssertEqual(described["text"], .string(""))
    XCTAssertEqual(described["placeholder"], .string("Enter text"))
    XCTAssertEqual(described["isEnabled"], .bool(true))
  }

  // MARK: - clear command

  func testClearWhenEnabled() {
    state.text = "Hello"
    state.isEnabled = true
    applyTextInputClear(to: &state)
    XCTAssertEqual(state.text, "")
  }

  func testClearWhenDisabled() {
    state.text = "Hello"
    state.isEnabled = false
    applyTextInputClear(to: &state)
    XCTAssertEqual(state.text, "Hello") // no-op
  }

  // MARK: - setProperty: text

  func testSetPropertyText() throws {
    let params = JSONValue.object([
      "key": .string("text"),
      "value": .string("New text")
    ])
    try applyTextInputSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.text, "New text")
  }

  func testSetPropertyTextEmpty() throws {
    state.text = "Initial"
    let params = JSONValue.object([
      "key": .string("text"),
      "value": .string("")
    ])
    try applyTextInputSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.text, "")
  }

  // MARK: - setProperty: placeholder

  func testSetPropertyPlaceholder() throws {
    let params = JSONValue.object([
      "key": .string("placeholder"),
      "value": .string("Type here...")
    ])
    try applyTextInputSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.placeholder, "Type here...")
  }

  // MARK: - setProperty: isEnabled

  func testSetPropertyIsEnabledFalse() throws {
    let params = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .bool(false)
    ])
    try applyTextInputSetProperty(to: &state, parameters: params)
    XCTAssertFalse(state.isEnabled)
  }

  func testSetPropertyIsEnabledTrue() throws {
    state.isEnabled = false
    let params = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .bool(true)
    ])
    try applyTextInputSetProperty(to: &state, parameters: params)
    XCTAssertTrue(state.isEnabled)
  }

  // MARK: - setProperty: Invalid cases

  func testSetPropertyInvalidKey() throws {
    let params = JSONValue.object([
      "key": .string("unknownKey"),
      "value": .string("value")
    ])
    XCTAssertThrowsError(try applyTextInputSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.unknownCommand = error else {
        XCTFail("Expected unknownCommand")
        return
      }
    }
  }

  func testSetPropertyTextWithWrongType() throws {
    let params = JSONValue.object([
      "key": .string("text"),
      "value": .int(123) // wrong type: should be string
    ])
    XCTAssertThrowsError(try applyTextInputSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyMissingKey() throws {
    let params = JSONValue.object([
      "value": .string("text")
    ])
    XCTAssertThrowsError(try applyTextInputSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyInvalidParameterStructure() throws {
    let params = JSONValue.string("invalid")
    XCTAssertThrowsError(try applyTextInputSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  // MARK: - Round-trip

  func testRoundTripTextInputState() throws {
    state.text = "Hello World"
    state.placeholder = "Custom placeholder"
    state.isEnabled = false

    var described = makeTextInputDescribedState(state)
    XCTAssertEqual(described["text"], .string("Hello World"))
    XCTAssertEqual(described["placeholder"], .string("Custom placeholder"))
    XCTAssertEqual(described["isEnabled"], .bool(false))

    // Modify via setProperty
    let params = JSONValue.object([
      "key": .string("text"),
      "value": .string("Modified")
    ])
    try applyTextInputSetProperty(to: &state, parameters: params)

    described = makeTextInputDescribedState(state)
    XCTAssertEqual(described["text"], .string("Modified"))
  }
}
