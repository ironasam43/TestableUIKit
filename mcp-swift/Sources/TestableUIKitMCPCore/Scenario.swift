//
//  Scenario.swift
//  TestableUIKitMCPCore
//
//  宣言的 UI シナリオ（ui_runScenario）の純粋モデル・パース・assert 評価。
//  HTTP / swift-sdk に一切依存しない Foundation only の層。
//  main.swift（executable）はここでパースしたステップ列を POST /perform で
//  順に送信し、返却 describedState を evaluateExpect に通すだけの薄い
//  オーケストレーションに徹する。
//
//  シナリオ形式:
//    {
//      "name": "counter-flow",
//      "steps": [
//        {
//          "action": "tap",            // 実行コマンド名（getState/tap/setProperty/setEnabled等。
//                                       // /perform の commandName にそのまま渡す）
//          "testID": "scene.demo.counter",
//          "parameters": { ... },      // 省略可
//          "expect": { "count": 1 }    // 省略可。describedState とキー単位で突合
//        }
//      ]
//    }
//

import Foundation

// ================================================================
// JSONValue — 汎用 JSON 値（Codable・Foundation only）
// ================================================================

/// シナリオの parameters / expect / describedState を表現する汎用 JSON 値。
///
/// メインライブラリ（TestableUIKit）にも同名の型があるが、本パッケージは
/// 意図的にメインライブラリを import しない独立 sub-package のため、
/// ここで最小限の互換型を自前定義する。
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
        in: container, debugDescription: "サポートされていない JSON 値")
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
  /// `.object` の場合のみ辞書を返す（それ以外は nil）。
  public var objectValue: [String: JSONValue]? {
    if case .object(let o) = self { return o }
    return nil
  }
}

// ================================================================
// シナリオモデル（Codable）
// ================================================================

/// シナリオ 1 ステップ。
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

/// 宣言的シナリオ全体（複数ステップの線形列）。
public struct Scenario: Codable, Equatable, Sendable {
  public let name: String
  public let steps: [ScenarioStep]

  public init(name: String, steps: [ScenarioStep]) {
    self.name = name
    self.steps = steps
  }
}

// ================================================================
// ScenarioParser — JSON → Scenario（純粋）
// ================================================================

public enum ScenarioParseError: Error, CustomStringConvertible {
  case invalidUTF8

  public var description: String {
    switch self {
    case .invalidUTF8: return "シナリオ JSON の UTF-8 デコードに失敗しました"
    }
  }
}

public enum ScenarioParser {
  /// JSON データからシナリオをパースする。
  public static func parse(json data: Data) throws -> Scenario {
    return try JSONDecoder().decode(Scenario.self, from: data)
  }

  /// JSON 文字列からシナリオをパースする。
  public static func parse(jsonString: String) throws -> Scenario {
    guard let data = jsonString.data(using: .utf8) else {
      throw ScenarioParseError.invalidUTF8
    }
    return try parse(json: data)
  }
}

// ================================================================
// assert 評価結果・ステップ結果・シナリオ結果（Codable）
// ================================================================

/// 1 キーぶんの assert 判定結果。
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

/// 1 ステップぶんの実行結果。
public struct StepResult: Codable, Equatable, Sendable {
  public let index: Int
  public let action: String
  public let testID: String
  /// /perform 呼び出し自体（HTTP・コマンド実行）が成功したか。
  public let success: Bool
  /// success == false の場合のエラーメッセージ。
  public let error: String?
  public let describedState: [String: JSONValue]?
  public let asserts: [AssertResult]
  /// success かつ全 assert が pass の場合のみ true。
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

/// シナリオ全体の実行結果。
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
// ScenarioEvaluator — 純粋 assert 評価・集約
// ================================================================

public enum ScenarioEvaluator {

  /// 数値比較の許容誤差。
  static let numberEpsilon = 1e-9

  /// `expect` 辞書と実際の describedState を突合し AssertResult 配列を返す。
  ///
  /// - expected に列挙されたキーのみを判定する（actual 側の余剰キーは無視）。
  /// - actual にキーが存在しない場合は fail。
  /// - number は微小誤差を許容して比較、それ以外は完全一致。
  /// - キー順は決定的（expected のキーをソートした順）。
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

  /// JSONValue 同士の等価判定（number のみ epsilon 許容）。
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

  /// ステップ結果列から pass/fail を集約する（純粋関数）。
  public static func aggregate(
    stepResults: [StepResult]
  ) -> (passed: Bool, passCount: Int, failCount: Int) {
    let passCount = stepResults.filter { $0.passed }.count
    let failCount = stepResults.count - passCount
    return (failCount == 0, passCount, failCount)
  }

  /// ステップ結果列からシナリオ全体の結果を組み立てる。
  public static func buildScenarioResult(
    name: String, stepResults: [StepResult]
  ) -> ScenarioResult {
    let (passed, passCount, failCount) = aggregate(stepResults: stepResults)
    return ScenarioResult(
      name: name, stepResults: stepResults, passed: passed, passCount: passCount,
      failCount: failCount)
  }
}
