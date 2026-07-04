//
//  Scenario.swift
//  TestableUIKitMCPCore
//
//  Pure model, parsing, and assert evaluation for declarative UI scenarios (ui_runScenario).
//  Foundation-only layer with no dependency on HTTP or swift-sdk.
//  main.swift (executable) performs only thin orchestration: it sends parsed steps via
//  POST /perform in order and passes the returned describedState to evaluateExpect.
//
//  Scenario format:
//    {
//      "name": "counter-flow",
//      "steps": [
//        {
//          "action": "tap",            // command to execute (getState/tap/setProperty/setEnabled, etc.)
//                                       // passed directly to /perform as commandName
//          "testID": "scene.demo.counter",
//          "parameters": { ... },      // optional
//          "expect": { "count": 1 }    // optional; matched key-by-key against describedState
//        }
//      ]
//    }
//

import Foundation

// ================================================================
// JSONValue — generic JSON value (Codable, Foundation only)
// ================================================================

/// Generic JSON value representing scenario parameters / expect / describedState.
///
/// The main library (TestableUIKit) defines a same-named type, but this package
/// intentionally does not import the main library (independent sub-package), so a
/// minimal compatible type is defined here.
public indirect enum JSONValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])
}

extension JSONValue: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let b = try? container.decode(Bool.self) {
      self = .bool(b)
    } else if let n = try? container.decode(Double.self) {
      self = .number(n)
    } else if let s = try? container.decode(String.self) {
      self = .string(s)
    } else if let a = try? container.decode([JSONValue].self) {
      self = .array(a)
    } else if let o = try? container.decode([String: JSONValue].self) {
      self = .object(o)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unsupported JSON value type")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let b): try container.encode(b)
    case .number(let n): try container.encode(n)
    case .string(let s): try container.encode(s)
    case .array(let a): try container.encode(a)
    case .object(let o): try container.encode(o)
    }
  }
}

extension JSONValue {
  /// Returns the dictionary when the value is `.object`; nil otherwise.
  public var objectValue: [String: JSONValue]? {
    if case .object(let o) = self { return o }
    return nil
  }
}

// ================================================================
// ScenarioAction — known command constants
// ================================================================

/// Known commands available in ui_runScenario.
/// Each value is passed directly to the /perform endpoint as commandName.
public enum ScenarioAction {
  /// Universal commands (valid for all testable components).
  public static let getState = "getState"
  public static let setProperty = "setProperty"

  /// Component-specific commands.
  public static let tap = "tap"
  public static let increment = "increment"
  public static let decrement = "decrement"
  public static let reset = "reset"
  public static let toggle = "toggle"
  public static let clear = "clear"
  public static let setEnabled = "setEnabled"

  /// Array of all known commands (for schema definitions and tests).
  public static let known = [
    getState, setProperty, tap, increment, decrement, reset, toggle, clear, setEnabled,
  ]
}

// ================================================================
// Scenario model (Codable)
// ================================================================

/// One step in a scenario.
public struct ScenarioStep: Codable, Equatable, Sendable {
  public let action: String
  public let testID: String
  public let parameters: JSONValue?
  public let expect: [String: JSONValue]?

  public init(
    action: String, testID: String, parameters: JSONValue? = nil,
    expect: [String: JSONValue]? = nil
  ) {
    self.action = action
    self.testID = testID
    self.parameters = parameters
    self.expect = expect
  }
}

/// A complete declarative scenario (linear sequence of steps).
public struct Scenario: Codable, Equatable, Sendable {
  public let name: String
  public let steps: [ScenarioStep]

  public init(name: String, steps: [ScenarioStep]) {
    self.name = name
    self.steps = steps
  }
}

// ================================================================
// ScenarioParser — JSON → Scenario (pure)
// ================================================================

public enum ScenarioParseError: Error, CustomStringConvertible {
  case invalidUTF8

  public var description: String {
    switch self {
    case .invalidUTF8: return "Failed to decode scenario JSON as UTF-8"
    }
  }
}

public enum ScenarioParser {
  /// Parses a scenario from JSON data.
  public static func parse(json data: Data) throws -> Scenario {
    return try JSONDecoder().decode(Scenario.self, from: data)
  }

  /// Parses a scenario from a JSON string.
  public static func parse(jsonString: String) throws -> Scenario {
    guard let data = jsonString.data(using: .utf8) else {
      throw ScenarioParseError.invalidUTF8
    }
    return try parse(json: data)
  }
}

// ================================================================
// Assert result, step result, scenario result (Codable)
// ================================================================

/// Assert evaluation result for a single key.
public struct AssertResult: Codable, Equatable, Sendable {
  public let key: String
  public let expected: JSONValue
  public let actual: JSONValue?
  public let passed: Bool

  public init(key: String, expected: JSONValue, actual: JSONValue?, passed: Bool) {
    self.key = key
    self.expected = expected
    self.actual = actual
    self.passed = passed
  }
}

/// Execution result for a single step.
public struct StepResult: Codable, Equatable, Sendable {
  public let index: Int
  public let action: String
  public let testID: String
  /// Whether the /perform call itself (HTTP + command execution) succeeded.
  public let success: Bool
  /// Error message when success == false.
  public let error: String?
  public let describedState: [String: JSONValue]?
  public let asserts: [AssertResult]
  /// true only when success is true and all asserts pass.
  public let passed: Bool

  public init(
    index: Int, action: String, testID: String, success: Bool, error: String?,
    describedState: [String: JSONValue]?, asserts: [AssertResult], passed: Bool
  ) {
    self.index = index
    self.action = action
    self.testID = testID
    self.success = success
    self.error = error
    self.describedState = describedState
    self.asserts = asserts
    self.passed = passed
  }
}

/// Execution result for an entire scenario.
public struct ScenarioResult: Codable, Equatable, Sendable {
  public let name: String
  public let stepResults: [StepResult]
  public let passed: Bool
  public let passCount: Int
  public let failCount: Int

  public init(
    name: String, stepResults: [StepResult], passed: Bool, passCount: Int, failCount: Int
  ) {
    self.name = name
    self.stepResults = stepResults
    self.passed = passed
    self.passCount = passCount
    self.failCount = failCount
  }
}

// ================================================================
// ScenarioEvaluator — pure assert evaluation and aggregation
// ================================================================

public enum ScenarioEvaluator {

  /// Tolerance for floating-point number comparisons.
  static let numberEpsilon = 1e-9

  /// Matches the `expect` dictionary against the actual describedState and returns AssertResult array.
  ///
  /// - Only keys listed in expected are evaluated (surplus keys in actual are ignored).
  /// - Missing keys in actual result in a fail.
  /// - Numbers are compared with epsilon tolerance; all other types require exact equality.
  /// - Key order is deterministic (sorted keys from expected).
  public static func evaluateExpect(
    expected: [String: JSONValue],
    actual: [String: JSONValue]
  ) -> [AssertResult] {
    return expected.keys.sorted().map { key in
      let exp = expected[key]!
      let act = actual[key]
      let passed = act.map { jsonValuesEqual($0, exp) } ?? false
      return AssertResult(key: key, expected: exp, actual: act, passed: passed)
    }
  }

  /// Equality check for JSONValue pairs (epsilon tolerance for numbers only).
  static func jsonValuesEqual(_ a: JSONValue, _ b: JSONValue) -> Bool {
    switch (a, b) {
    case (.null, .null):
      return true
    case (.bool(let x), .bool(let y)):
      return x == y
    case (.string(let x), .string(let y)):
      return x == y
    case (.number(let x), .number(let y)):
      return abs(x - y) < numberEpsilon
    case (.array(let x), .array(let y)):
      guard x.count == y.count else { return false }
      return zip(x, y).allSatisfy { jsonValuesEqual($0, $1) }
    case (.object(let x), .object(let y)):
      guard Set(x.keys) == Set(y.keys) else { return false }
      return x.allSatisfy { k, v in y[k].map { jsonValuesEqual(v, $0) } ?? false }
    default:
      return false
    }
  }

  /// Aggregates step results into pass/fail counts (pure function).
  public static func aggregate(
    stepResults: [StepResult]
  ) -> (passed: Bool, passCount: Int, failCount: Int) {
    let passCount = stepResults.filter { $0.passed }.count
    let failCount = stepResults.count - passCount
    return (failCount == 0, passCount, failCount)
  }

  /// Builds an overall ScenarioResult from step results.
  public static func buildScenarioResult(
    name: String, stepResults: [StepResult]
  ) -> ScenarioResult {
    let (passed, passCount, failCount) = aggregate(stepResults: stepResults)
    return ScenarioResult(
      name: name, stepResults: stepResults, passed: passed, passCount: passCount,
      failCount: failCount)
  }
}
