import XCTest
import TestableUIKit
@testable import TestableUIKitDemo

final class CLIDemoLoginButtonTests: XCTestCase {
  private var button: CLIDemoLoginButton!

  override func setUp() {
    super.setUp()
    button = CLIDemoLoginButton()
  }

  override func tearDown() {
    button = nil
    super.tearDown()
  }

  // MARK: - setProperty: isEnabled

  func testSetProperty_isEnabled_true() async throws {
    // Initial state: isEnabled = true
    XCTAssertTrue(button.isEnabled)

    // Set isEnabled to false
    let params = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .bool(false)
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: params)

    // Verify state changed
    XCTAssertFalse(button.isEnabled)
    XCTAssertEqual(result["isEnabled"], .bool(false))
  }

  func testSetProperty_isEnabled_false() async throws {
    // Set initial state to false
    let disableParams = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .bool(false)
    ])
    _ = try await button.perform(commandName: "setProperty", parameters: disableParams)

    // Verify it's false
    XCTAssertFalse(button.isEnabled)

    // Set back to true
    let enableParams = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .bool(true)
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: enableParams)

    // Verify state changed
    XCTAssertTrue(button.isEnabled)
    XCTAssertEqual(result["isEnabled"], .bool(true))
  }

  // MARK: - setProperty: title

  func testSetProperty_title() async throws {
    // Initial state: title = "Log In"
    XCTAssertEqual(button.title, "Log In")

    // Change title
    let params = JSONValue.object([
      "key": .string("title"),
      "value": .string("Sign In")
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: params)

    // Verify state changed
    XCTAssertEqual(button.title, "Sign In")
    XCTAssertEqual(result["title"], .string("Sign In"))
  }

  func testSetProperty_title_empty() async throws {
    // Set title to empty string
    let params = JSONValue.object([
      "key": .string("title"),
      "value": .string("")
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: params)

    // Verify state changed
    XCTAssertEqual(button.title, "")
    XCTAssertEqual(result["title"], .string(""))
  }

  // MARK: - setProperty: Invalid cases

  func testSetProperty_invalidKey() async throws {
    let params = JSONValue.object([
      "key": .string("unknownProperty"),
      "value": .bool(true)
    ])

    // Should throw unknownCommand error
    do {
      _ = try await button.perform(commandName: "setProperty", parameters: params)
      XCTFail("Expected TestError.unknownCommand to be thrown")
    } catch TestError.unknownCommand(let cmd) {
      XCTAssertEqual(cmd, "setProperty.unknownProperty")
    }
  }

  func testSetProperty_missingKey() async throws {
    // Missing "key" in parameters
    let params = JSONValue.object([
      "value": .bool(true)
    ])

    do {
      _ = try await button.perform(commandName: "setProperty", parameters: params)
      XCTFail("Expected TestError.invalidParameters to be thrown")
    } catch TestError.invalidParameters {
      // Expected
    }
  }

  func testSetProperty_missingValue() async throws {
    // Missing "value" in parameters
    let params = JSONValue.object([
      "key": .string("isEnabled")
    ])

    do {
      _ = try await button.perform(commandName: "setProperty", parameters: params)
      XCTFail("Expected TestError.invalidParameters to be thrown")
    } catch TestError.invalidParameters {
      // Expected
    }
  }

  func testSetProperty_isEnabled_wrongType() async throws {
    // Trying to set isEnabled with string instead of bool
    let params = JSONValue.object([
      "key": .string("isEnabled"),
      "value": .string("true")  // Wrong type: should be bool
    ])

    do {
      _ = try await button.perform(commandName: "setProperty", parameters: params)
      XCTFail("Expected TestError.invalidParameters to be thrown")
    } catch TestError.invalidParameters {
      // Expected
    }
  }

  func testSetProperty_title_wrongType() async throws {
    // Trying to set title with bool instead of string
    let params = JSONValue.object([
      "key": .string("title"),
      "value": .bool(true)  // Wrong type: should be string
    ])

    do {
      _ = try await button.perform(commandName: "setProperty", parameters: params)
      XCTFail("Expected TestError.invalidParameters to be thrown")
    } catch TestError.invalidParameters {
      // Expected
    }
  }

  func testSetProperty_notObject() async throws {
    // Parameters is not an object
    let params = JSONValue.string("invalid")

    do {
      _ = try await button.perform(commandName: "setProperty", parameters: params)
      XCTFail("Expected TestError.invalidParameters to be thrown")
    } catch TestError.invalidParameters {
      // Expected
    }
  }

  // MARK: - tap command (existing)

  func testTap() async throws {
    // Initial state: isEnabled = true
    XCTAssertTrue(button.isEnabled)

    // Execute tap
    let result = try await button.perform(commandName: "tap", parameters: .null)

    // Verify state changed
    XCTAssertFalse(button.isEnabled)
    XCTAssertEqual(result["isEnabled"], .bool(false))
  }
}
