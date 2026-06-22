import XCTest
import TestableUIKit

final class OnOffSwitchCoreTests: XCTestCase {
  private var state: OnOffSwitchState!

  override func setUp() {
    super.setUp()
    state = OnOffSwitchState()
  }

  override func tearDown() {
    state = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertFalse(state.isOn)
    XCTAssertEqual(state.label, "Switch")
    XCTAssertTrue(state.isEnabled)
  }

  func testDescribedStateInitial() {
    let described = makeOnOffSwitchDescribedState(state)
    XCTAssertEqual(described["isOn"], .bool(false))
    XCTAssertEqual(described["label"], .string("Switch"))
    XCTAssertEqual(described["isEnabled"], .bool(true))
  }

  // MARK: - toggle command

  func testToggleWhenEnabledOff() {
    state.isOn = false
    state.isEnabled = true
    applyOnOffSwitchToggle(to: &state)
    XCTAssertTrue(state.isOn)
  }

  func testToggleWhenEnabledOn() {
    state.isOn = true
    state.isEnabled = true
    applyOnOffSwitchToggle(to: &state)
    XCTAssertFalse(state.isOn)
  }

  func testToggleWhenDisabled() {
    state.isOn = false
    state.isEnabled = false
    applyOnOffSwitchToggle(to: &state)
    XCTAssertFalse(state.isOn) // no-op
  }

  func testToggleMultipleTimes() {
    state.isEnabled = true
    applyOnOffSwitchToggle(to: &state)
    XCTAssertTrue(state.isOn)
    applyOnOffSwitchToggle(to: &state)
    XCTAssertFalse(state.isOn)
  }

  // MARK: - setProperty: isOn

  func testSetPropertyIsOnTrue() throws {
    let params = JSONValue.object([
      "key": .string("isOn"),
      "value": .bool(true)
    ])
    try applyOnOffSwitchSetProperty(to: &state, parameters: params)
    XCTAssertTrue(state.isOn)
  }

  func testSetPropertyIsOnFalse() throws {
    state.isOn = true
    let params = JSONValue.object([
      "key": .string("isOn"),
      "value": .bool(false)
    ])
    try applyOnOffSwitchSetProperty(to: &state, parameters: params)
    XCTAssertFalse(state.isOn)
  }

  // MARK: - setProperty: label

  func testSetPropertyLabel() throws {
    let params = JSONValue.object([
      "key": .string("label"),
      "value": .string("Power")
    ])
    try applyOnOffSwitchSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.label, "Power")
  }

  // MARK: - setProperty: isEnabled

  func testSetPropertyIsEnabledFalse() throws {
    let params = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .bool(false)
    ])
    try applyOnOffSwitchSetProperty(to: &state, parameters: params)
    XCTAssertFalse(state.isEnabled)
  }

  func testSetPropertyIsEnabledTrue() throws {
    state.isEnabled = false
    let params = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .bool(true)
    ])
    try applyOnOffSwitchSetProperty(to: &state, parameters: params)
    XCTAssertTrue(state.isEnabled)
  }

  // MARK: - setProperty: Invalid cases

  func testSetPropertyInvalidKey() throws {
    let params = JSONValue.object([
      "key": .string("unknownKey"),
      "value": .bool(true)
    ])
    XCTAssertThrowsError(try applyOnOffSwitchSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.unknownCommand = error else {
        XCTFail("Expected unknownCommand")
        return
      }
    }
  }

  func testSetPropertyIsOnWithWrongType() throws {
    let params = JSONValue.object([
      "key": .string("isOn"),
      "value": .string("true") // wrong type: should be bool
    ])
    XCTAssertThrowsError(try applyOnOffSwitchSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyLabelWithWrongType() throws {
    let params = JSONValue.object([
      "key": .string("label"),
      "value": .int(123) // wrong type: should be string
    ])
    XCTAssertThrowsError(try applyOnOffSwitchSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyMissingValue() throws {
    let params = JSONValue.object([
      "key": .string("isOn")
    ])
    XCTAssertThrowsError(try applyOnOffSwitchSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyInvalidParameterStructure() throws {
    let params = JSONValue.int(123) // non-object type
    XCTAssertThrowsError(try applyOnOffSwitchSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  // MARK: - Round-trip

  func testRoundTripOnOffSwitchState() throws {
    state.isOn = true
    state.label = "WiFi"
    state.isEnabled = false

    var described = makeOnOffSwitchDescribedState(state)
    XCTAssertEqual(described["isOn"], .bool(true))
    XCTAssertEqual(described["label"], .string("WiFi"))
    XCTAssertEqual(described["isEnabled"], .bool(false))

    // Modify via setProperty
    let params = JSONValue.object([
      "key": .string("isOn"),
      "value": .bool(false)
    ])
    try applyOnOffSwitchSetProperty(to: &state, parameters: params)

    described = makeOnOffSwitchDescribedState(state)
    XCTAssertEqual(described["isOn"], .bool(false))
  }
}
