//
//  ScenarioTests.swift
//  TestableUIKitMCPCoreTests
//
//  L1 テスト: 宣言的シナリオ（ui_runScenario）のパース・assert 評価・集約。
//  HTTP / swift-sdk / Simulator 不要（純粋関数のみ）。
//

import XCTest

@testable import TestableUIKitMCPCore

// ================================================================
// ScenarioParser
// ================================================================

final class ScenarioParserTests: XCTestCase {
  func test_parse_minimal_scenario() throws {
    let json = """
      { "name": "counter-flow", "steps": [
        { "action": "getState", "testID": "scene.demo.counter" }
      ] }
      """
    let scenario = try ScenarioParser.parse(jsonString: json)
    XCTAssertEqual(scenario.name, "counter-flow")
    XCTAssertEqual(scenario.steps.count, 1)
    XCTAssertEqual(scenario.steps[0].action, "getState")
    XCTAssertEqual(scenario.steps[0].testID, "scene.demo.counter")
    XCTAssertNil(scenario.steps[0].parameters)
    XCTAssertNil(scenario.steps[0].expect)
  }

  func test_parse_step_with_parameters_and_expect() throws {
    let json = """
      { "name": "s", "steps": [
        {
          "action": "setProperty",
          "testID": "scene.demo.counter",
          "parameters": { "key": "isEnabled", "value": false },
          "expect": { "isEnabled": false, "count": 3 }
        }
      ] }
      """
    let scenario = try ScenarioParser.parse(jsonString: json)
    let step = scenario.steps[0]
    XCTAssertEqual(step.parameters?.objectValue?["key"], .string("isEnabled"))
    XCTAssertEqual(step.parameters?.objectValue?["value"], .bool(false))
    XCTAssertEqual(step.expect?["isEnabled"], .bool(false))
    XCTAssertEqual(step.expect?["count"], .number(3))
  }

  func test_parse_multiple_steps_preserves_order() throws {
    let json = """
      { "name": "s", "steps": [
        { "action": "getState", "testID": "a" },
        { "action": "tap", "testID": "b" },
        { "action": "increment", "testID": "c" }
      ] }
      """
    let scenario = try ScenarioParser.parse(jsonString: json)
    XCTAssertEqual(scenario.steps.map { $0.action }, ["getState", "tap", "increment"])
    XCTAssertEqual(scenario.steps.map { $0.testID }, ["a", "b", "c"])
  }

  func test_parse_invalid_json_throws() {
    XCTAssertThrowsError(try ScenarioParser.parse(jsonString: "{ not valid json"))
  }

  func test_parse_missing_required_field_throws() {
    let json = #"{ "steps": [] }"#  // name 欠落
    XCTAssertThrowsError(try ScenarioParser.parse(jsonString: json))
  }

  func test_parse_empty_steps_ok() throws {
    let scenario = try ScenarioParser.parse(jsonString: #"{ "name": "empty", "steps": [] }"#)
    XCTAssertEqual(scenario.steps.count, 0)
  }
}

// ================================================================
// ScenarioEvaluator.evaluateExpect
// ================================================================

final class EvaluateExpectTests: XCTestCase {
  func test_all_pass() {
    let expected: [String: JSONValue] = ["isEnabled": .bool(true), "title": .string("Log In")]
    let actual: [String: JSONValue] = [
      "isEnabled": .bool(true), "title": .string("Log In"), "alpha": .number(1.0),
    ]
    let results = ScenarioEvaluator.evaluateExpect(expected: expected, actual: actual)
    XCTAssertEqual(results.count, 2)
    XCTAssertTrue(results.allSatisfy { $0.passed })
  }

  func test_mismatch_fails() {
    let expected: [String: JSONValue] = ["count": .number(1)]
    let actual: [String: JSONValue] = ["count": .number(2)]
    let results = ScenarioEvaluator.evaluateExpect(expected: expected, actual: actual)
    XCTAssertEqual(results.count, 1)
    XCTAssertFalse(results[0].passed)
    XCTAssertEqual(results[0].actual, .number(2))
  }

  func test_missing_actual_key_fails() {
    let expected: [String: JSONValue] = ["isHidden": .bool(false)]
    let actual: [String: JSONValue] = ["isEnabled": .bool(true)]
    let results = ScenarioEvaluator.evaluateExpect(expected: expected, actual: actual)
    XCTAssertFalse(results[0].passed)
    XCTAssertNil(results[0].actual)
  }

  func test_actual_extra_keys_ignored() {
    let expected: [String: JSONValue] = ["count": .number(1)]
    let actual: [String: JSONValue] = ["count": .number(1), "isEnabled": .bool(true)]
    let results = ScenarioEvaluator.evaluateExpect(expected: expected, actual: actual)
    XCTAssertEqual(results.count, 1)
    XCTAssertTrue(results[0].passed)
  }

  func test_number_epsilon_tolerance() {
    let expected: [String: JSONValue] = ["alpha": .number(1.0)]
    let actual: [String: JSONValue] = ["alpha": .number(1.0 + 1e-12)]
    let results = ScenarioEvaluator.evaluateExpect(expected: expected, actual: actual)
    XCTAssertTrue(results[0].passed)
  }

  func test_number_beyond_epsilon_fails() {
    let expected: [String: JSONValue] = ["alpha": .number(1.0)]
    let actual: [String: JSONValue] = ["alpha": .number(1.01)]
    let results = ScenarioEvaluator.evaluateExpect(expected: expected, actual: actual)
    XCTAssertFalse(results[0].passed)
  }

  func test_deterministic_key_order() {
    let expected: [String: JSONValue] = [
      "isHidden": .bool(false), "alpha": .number(1), "title": .string("x"),
    ]
    let actual: [String: JSONValue] = [
      "isHidden": .bool(false), "alpha": .number(1), "title": .string("x"),
    ]
    let results = ScenarioEvaluator.evaluateExpect(expected: expected, actual: actual)
    XCTAssertEqual(results.map { $0.key }, ["alpha", "isHidden", "title"])
  }

  func test_empty_expected_yields_empty_results() {
    let results = ScenarioEvaluator.evaluateExpect(expected: [:], actual: ["a": .bool(true)])
    XCTAssertTrue(results.isEmpty)
  }
}

// ================================================================
// ScenarioEvaluator.aggregate / buildScenarioResult
// ================================================================

final class AggregateTests: XCTestCase {
  private func makeStepResult(passed: Bool, index: Int = 0) -> StepResult {
    StepResult(
      index: index, action: "getState", testID: "t", success: passed, error: nil,
      describedState: nil, asserts: [], passed: passed)
  }

  func test_all_pass_aggregate() {
    let results = [makeStepResult(passed: true), makeStepResult(passed: true)]
    let agg = ScenarioEvaluator.aggregate(stepResults: results)
    XCTAssertTrue(agg.passed)
    XCTAssertEqual(agg.passCount, 2)
    XCTAssertEqual(agg.failCount, 0)
  }

  func test_one_fail_aggregate() {
    let results = [makeStepResult(passed: true), makeStepResult(passed: false)]
    let agg = ScenarioEvaluator.aggregate(stepResults: results)
    XCTAssertFalse(agg.passed)
    XCTAssertEqual(agg.passCount, 1)
    XCTAssertEqual(agg.failCount, 1)
  }

  func test_empty_steps_aggregate_passes() {
    let agg = ScenarioEvaluator.aggregate(stepResults: [])
    XCTAssertTrue(agg.passed)
    XCTAssertEqual(agg.passCount, 0)
    XCTAssertEqual(agg.failCount, 0)
  }

  func test_build_scenario_result() {
    let results = [makeStepResult(passed: true), makeStepResult(passed: false, index: 1)]
    let scenarioResult = ScenarioEvaluator.buildScenarioResult(name: "s", stepResults: results)
    XCTAssertEqual(scenarioResult.name, "s")
    XCTAssertFalse(scenarioResult.passed)
    XCTAssertEqual(scenarioResult.passCount, 1)
    XCTAssertEqual(scenarioResult.failCount, 1)
    XCTAssertEqual(scenarioResult.stepResults.count, 2)
  }
}

// ================================================================
// JSONValue round-trip（Codable）
// ================================================================

final class JSONValueCodableTests: XCTestCase {
  func test_roundtrip_object() throws {
    let value: JSONValue = .object([
      "a": .bool(true), "b": .string("x"), "c": .number(1.5), "d": .null,
      "e": .array([.number(1), .number(2)]),
    ])
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
    XCTAssertEqual(decoded, value)
  }

  func test_decode_scenario_step_response_shape() throws {
    let json = #"{"isEnabled":true,"title":"Log In","isHidden":false,"alpha":1,"backgroundColor":"systemBlue"}"#
    let decoded = try JSONDecoder().decode(JSONValue.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(decoded.objectValue?["isEnabled"], .bool(true))
    XCTAssertEqual(decoded.objectValue?["title"], .string("Log In"))
  }
}

// ================================================================
// ScenarioAction（既知コマンド定数）
// ================================================================

final class ScenarioActionTests: XCTestCase {
  func test_knownActionsContainsExpectedValues() {
    // ユニバーサルコマンド
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.getState))
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.setProperty))

    // コンポーネント固有コマンド
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.tap))
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.increment))
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.decrement))
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.reset))
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.toggle))
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.clear))
    XCTAssertTrue(ScenarioAction.known.contains(ScenarioAction.setEnabled))
  }

  func test_knownActionsAreUnique() {
    let unique = Set(ScenarioAction.known)
    XCTAssertEqual(unique.count, ScenarioAction.known.count, "ScenarioAction.known に重複があります")
  }

  func test_knownActionsHaveCorrectValues() {
    XCTAssertEqual(ScenarioAction.getState, "getState")
    XCTAssertEqual(ScenarioAction.setProperty, "setProperty")
    XCTAssertEqual(ScenarioAction.tap, "tap")
    XCTAssertEqual(ScenarioAction.increment, "increment")
    XCTAssertEqual(ScenarioAction.decrement, "decrement")
    XCTAssertEqual(ScenarioAction.reset, "reset")
    XCTAssertEqual(ScenarioAction.toggle, "toggle")
    XCTAssertEqual(ScenarioAction.clear, "clear")
    XCTAssertEqual(ScenarioAction.setEnabled, "setEnabled")
  }

  func test_knownActionsCountMatchesExpectation() {
    // 9 つのコマンドが定義されていることを確認
    XCTAssertEqual(ScenarioAction.known.count, 9)
  }
}
