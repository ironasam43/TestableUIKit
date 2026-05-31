import XCTest
@testable import TestableUIKit

final class JSONValueTests: XCTestCase {

  // Wire format: bool → "true" であること（タグ付きではない）
  func testBoolWireFormat() throws {
    let value = JSONValue.bool(true)
    let data = try JSONEncoder().encode(value)
    let encoded = String(data: data, encoding: .utf8)
    XCTAssertEqual(encoded, "true", "bool(true) should encode to 'true'")
  }

  // Wire format: string → "Log In" であること（エスケープされた JSON 文字列）
  func testStringWireFormat() throws {
    let value = JSONValue.string("Log In")
    let data = try JSONEncoder().encode(value)
    let encoded = String(data: data, encoding: .utf8)
    XCTAssertEqual(encoded, #""Log In""#, "string should encode with quotes")
  }

  // Wire format: object の完成形
  func testObjectWireFormat() throws {
    let state: [String: JSONValue] = [
      "isEnabled": .bool(false),
      "title": .string("Log In")
    ]
    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)

    XCTAssertEqual(decoded["isEnabled"], .bool(false), "isEnabled should be false")
    XCTAssertEqual(decoded["title"], .string("Log In"), "title should be 'Log In'")
  }

  // Wire format: null → "null"
  func testNullWireFormat() throws {
    let value = JSONValue.null
    let data = try JSONEncoder().encode(value)
    let encoded = String(data: data, encoding: .utf8)
    XCTAssertEqual(encoded, "null", "null should encode to 'null'")
  }

  // Decode: null を decode して .null ケースになることを確認
  func testNullDecode() throws {
    let data = Data("null".utf8)
    let value = try JSONDecoder().decode(JSONValue.self, from: data)
    XCTAssertEqual(value, .null, "null should decode to .null case")
  }

  // Decode: JSON object を [String: JSONValue] に decode
  func testObjectDecode() throws {
    let json = #"{"isEnabled":false,"title":"Log In"}"#
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)

    XCTAssertEqual(decoded["isEnabled"], .bool(false))
    XCTAssertEqual(decoded["title"], .string("Log In"))
  }
}
