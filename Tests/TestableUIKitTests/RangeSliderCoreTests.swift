import XCTest
import TestableUIKit

final class RangeSliderCoreTests: XCTestCase {
  private var state: RangeSliderState!

  override func setUp() {
    super.setUp()
    state = RangeSliderState()
  }

  override func tearDown() {
    state = nil
    super.tearDown()
  }

  // MARK: - Initial State

  func testInitialState() {
    XCTAssertEqual(state.value, 50.0)
    XCTAssertEqual(state.minValue, 0.0)
    XCTAssertEqual(state.maxValue, 100.0)
    XCTAssertEqual(state.step, 1.0)
  }

  func testDescribedStateInitial() {
    let described = makeRangeSliderDescribedState(state)
    XCTAssertEqual(described["value"], .double(50.0))
    XCTAssertEqual(described["minValue"], .double(0.0))
    XCTAssertEqual(described["maxValue"], .double(100.0))
    XCTAssertEqual(described["step"], .double(1.0))
  }

  // MARK: - reset command

  func testResetToMiddle() {
    state.minValue = 0.0
    state.maxValue = 100.0
    state.value = 75.0
    applyRangeSliderReset(to: &state)
    XCTAssertEqual(state.value, 50.0) // (100 - 0) / 2 + 0
  }

  func testResetWithDifferentRange() {
    state.minValue = 10.0
    state.maxValue = 30.0
    state.value = 25.0
    applyRangeSliderReset(to: &state)
    XCTAssertEqual(state.value, 20.0) // (30 - 10) / 2 + 10
  }

  func testResetWithNegativeRange() {
    state.minValue = -50.0
    state.maxValue = 50.0
    state.value = 100.0
    applyRangeSliderReset(to: &state)
    XCTAssertEqual(state.value, 0.0) // (50 - (-50)) / 2 + (-50)
  }

  // MARK: - setProperty: value

  func testSetPropertyValue() throws {
    let params = JSONValue.object([
      "key": .string("value"),
      "value": .double(75.5)
    ])
    try applyRangeSliderSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.value, 75.5)
  }

  func testSetPropertyValueZero() throws {
    let params = JSONValue.object([
      "key": .string("value"),
      "value": .double(0.0)
    ])
    try applyRangeSliderSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.value, 0.0)
  }

  func testSetPropertyValueNegative() throws {
    let params = JSONValue.object([
      "key": .string("value"),
      "value": .double(-10.5)
    ])
    try applyRangeSliderSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.value, -10.5)
  }

  // MARK: - setProperty: minValue

  func testSetPropertyMinValue() throws {
    let params = JSONValue.object([
      "key": .string("minValue"),
      "value": .double(-100.0)
    ])
    try applyRangeSliderSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.minValue, -100.0)
  }

  // MARK: - setProperty: maxValue

  func testSetPropertyMaxValue() throws {
    let params = JSONValue.object([
      "key": .string("maxValue"),
      "value": .double(200.0)
    ])
    try applyRangeSliderSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.maxValue, 200.0)
  }

  // MARK: - setProperty: step

  func testSetPropertyStep() throws {
    let params = JSONValue.object([
      "key": .string("step"),
      "value": .double(0.5)
    ])
    try applyRangeSliderSetProperty(to: &state, parameters: params)
    XCTAssertEqual(state.step, 0.5)
  }

  // MARK: - setProperty: Invalid cases

  func testSetPropertyInvalidKey() throws {
    let params = JSONValue.object([
      "key": .string("unknownKey"),
      "value": .double(50.0)
    ])
    XCTAssertThrowsError(try applyRangeSliderSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.unknownCommand = error else {
        XCTFail("Expected unknownCommand")
        return
      }
    }
  }

  func testSetPropertyValueWithWrongType() throws {
    let params = JSONValue.object([
      "key": .string("value"),
      "value": .string("50.0") // wrong type: should be double
    ])
    XCTAssertThrowsError(try applyRangeSliderSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyMinValueWithWrongType() throws {
    let params = JSONValue.object([
      "key": .string("minValue"),
      "value": .int(10) // wrong type: should be double
    ])
    XCTAssertThrowsError(try applyRangeSliderSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyMissingKey() throws {
    let params = JSONValue.object([
      "value": .double(50.0)
    ])
    XCTAssertThrowsError(try applyRangeSliderSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  func testSetPropertyInvalidParameterStructure() throws {
    let params = JSONValue.double(50.0)
    XCTAssertThrowsError(try applyRangeSliderSetProperty(to: &state, parameters: params)) { error in
      guard case TestError.invalidParameters = error else {
        XCTFail("Expected invalidParameters")
        return
      }
    }
  }

  // MARK: - Round-trip

  func testRoundTripRangeSliderState() throws {
    state.value = 75.0
    state.minValue = 0.0
    state.maxValue = 100.0
    state.step = 5.0

    var described = makeRangeSliderDescribedState(state)
    XCTAssertEqual(described["value"], .double(75.0))
    XCTAssertEqual(described["step"], .double(5.0))

    // Modify via setProperty
    let params = JSONValue.object([
      "key": .string("value"),
      "value": .double(25.0)
    ])
    try applyRangeSliderSetProperty(to: &state, parameters: params)

    described = makeRangeSliderDescribedState(state)
    XCTAssertEqual(described["value"], .double(25.0))
  }
}
