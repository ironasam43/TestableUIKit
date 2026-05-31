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

  // MARK: - setProperty: isHidden

  func testSetProperty_isHidden_true() async throws {
    // Initial state: isHidden = false
    XCTAssertFalse(button.describedState["isHidden"] == .bool(true))

    // Set isHidden to true
    let params = JSONValue.object([
      "key": .string("isHidden"),
      "value": .bool(true)
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: params)

    // Verify state changed
    XCTAssertEqual(result["isHidden"], .bool(true))
  }

  func testSetProperty_isHidden_false() async throws {
    // Set initial state to true
    let hideParams = JSONValue.object([
      "key": .string("isHidden"),
      "value": .bool(true)
    ])
    _ = try await button.perform(commandName: "setProperty", parameters: hideParams)

    // Verify it's true
    XCTAssertEqual(button.describedState["isHidden"], .bool(true))

    // Set back to false
    let showParams = JSONValue.object([
      "key": .string("isHidden"),
      "value": .bool(false)
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: showParams)

    // Verify state changed
    XCTAssertEqual(result["isHidden"], .bool(false))
  }

  // MARK: - setProperty: alpha

  func testSetProperty_alpha_valid() async throws {
    // Initial state: alpha = 1.0
    XCTAssertEqual(button.describedState["alpha"], .double(1.0))

    // Change alpha to 0.5
    let params = JSONValue.object([
      "key": .string("alpha"),
      "value": .double(0.5)
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: params)

    // Verify state changed
    XCTAssertEqual(result["alpha"], .double(0.5))
  }

  func testSetProperty_alpha_boundary() async throws {
    // Test boundary: alpha = 0.0
    let zeroParams = JSONValue.object([
      "key": .string("alpha"),
      "value": .double(0.0)
    ])
    let resultZero = try await button.perform(commandName: "setProperty", parameters: zeroParams)
    XCTAssertEqual(resultZero["alpha"], .double(0.0))

    // Test boundary: alpha = 1.0
    let oneParams = JSONValue.object([
      "key": .string("alpha"),
      "value": .double(1.0)
    ])
    let resultOne = try await button.perform(commandName: "setProperty", parameters: oneParams)
    XCTAssertEqual(resultOne["alpha"], .double(1.0))
  }

  // MARK: - setProperty: backgroundColor

  func testSetProperty_backgroundColor_valid() async throws {
    // Initial state: backgroundColor = "systemBlue"
    XCTAssertEqual(button.describedState["backgroundColor"], .string("systemBlue"))

    // Change backgroundColor
    let params = JSONValue.object([
      "key": .string("backgroundColor"),
      "value": .string("systemRed")
    ])
    let result = try await button.perform(commandName: "setProperty", parameters: params)

    // Verify state changed
    XCTAssertEqual(result["backgroundColor"], .string("systemRed"))
  }

  func testSetProperty_backgroundColor_invalidType() async throws {
    // Trying to set backgroundColor with number instead of string
    let params = JSONValue.object([
      "key": .string("backgroundColor"),
      "value": .double(0xFF0000)  // Wrong type: should be string
    ])

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
