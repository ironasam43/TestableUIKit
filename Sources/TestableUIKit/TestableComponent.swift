import Foundation

// MARK: - TestableProperty
//
// Represents a get/set pair for a single property of State.
// Encapsulates bidirectional conversion between JSONValue and a State property.
// Convenience initializers (.bool/.int/.double/.string) automatically derive
// get/set from a WritableKeyPath. Type mismatches throw TestError.invalidParameters inside set.

public struct TestableProperty<State> {
  /// Extracts a JSONValue from state
  public let get: (State) -> JSONValue
  /// Writes a JSONValue back to state (throws on type mismatch)
  public let set: (inout State, JSONValue) throws -> Void

  public init(
    get: @escaping (State) -> JSONValue,
    set: @escaping (inout State, JSONValue) throws -> Void
  ) {
    self.get = get
    self.set = set
  }

  // MARK: - KeyPath-Based Convenience Initializers

  /// For Bool properties
  public static func bool(_ kp: WritableKeyPath<State, Bool>) -> TestableProperty<State> {
    TestableProperty(
      get: { .bool($0[keyPath: kp]) },
      set: { state, value in
        guard case .bool(let b) = value else { throw TestError.invalidParameters }
        state[keyPath: kp] = b
      }
    )
  }

  /// For Int properties
  public static func int(_ kp: WritableKeyPath<State, Int>) -> TestableProperty<State> {
    TestableProperty(
      get: { .int($0[keyPath: kp]) },
      set: { state, value in
        guard case .int(let n) = value else { throw TestError.invalidParameters }
        state[keyPath: kp] = n
      }
    )
  }

  /// For Double properties (also accepts Int, converting to Double)
  public static func double(_ kp: WritableKeyPath<State, Double>) -> TestableProperty<State> {
    TestableProperty(
      get: { .double($0[keyPath: kp]) },
      set: { state, value in
        switch value {
        case .double(let d):
          state[keyPath: kp] = d
        case .int(let n):
          state[keyPath: kp] = Double(n)
        default:
          throw TestError.invalidParameters
        }
      }
    )
  }

  /// For String properties
  public static func string(_ kp: WritableKeyPath<State, String>) -> TestableProperty<State> {
    TestableProperty(
      get: { .string($0[keyPath: kp]) },
      set: { state, value in
        guard case .string(let s) = value else { throw TestError.invalidParameters }
        state[keyPath: kp] = s
      }
    )
  }
}

// MARK: - Mirror Fallback describe
//
// When neither a describe closure nor properties are provided,
// Mirror walks State's stored properties and auto-describes Bool/Int/Double/String value types.
// SwiftUI private types (e.g. Binding internals) are skipped; only own value types are included.

func mirrorDescribe<State>(_ state: State) -> [String: JSONValue] {
  var result: [String: JSONValue] = [:]
  let mirror = Mirror(reflecting: state)
  for child in mirror.children {
    guard let label = child.label else { continue }
    switch child.value {
    case let b as Bool:
      result[label] = .bool(b)
    case let n as Int:
      result[label] = .int(n)
    case let d as Double:
      result[label] = .double(d)
    case let s as String:
      result[label] = .string(s)
    default:
      // 自前値型限定: それ以外（SwiftUI private 型・複合型）は無視
      continue
    }
  }
  return result
}

// MARK: - 共有 perform ロジック
//
// TestableComponent と将来の bridge 実装で共有する perform の本体。
// state を inout で受け取り、コマンドを適用したうえで describe 結果を返す。
//
// - getState: 何もせず describe を返す
// - setProperty: parameters {"key","value"} を読み、該当 TestableProperty.set を呼ぶ
// - commands に一致: クロージャを実行して describe を返す
// - どれにも当たらない: TestError.unknownCommand を throw

func runTestablePerform<State>(
  commandName: String,
  parameters: JSONValue,
  state: inout State,
  properties: [String: TestableProperty<State>],
  commands: [String: (inout State, JSONValue) throws -> Void],
  describe: (State) -> [String: JSONValue]
) throws -> [String: JSONValue] {
  switch commandName {
  case "getState":
    return describe(state)
  case "setProperty":
    guard case .object(let dict) = parameters,
          case .string(let key) = dict["key"],
          let value = dict["value"] else {
      throw TestError.invalidParameters
    }
    guard let property = properties[key] else {
      throw TestError.unknownCommand("setProperty.\(key)")
    }
    try property.set(&state, value)
    return describe(state)
  default:
    if let command = commands[commandName] {
      try command(&state, parameters)
      return describe(state)
    }
    throw TestError.unknownCommand(commandName)
  }
}

// MARK: - TestableComponent（Tier 1）
//
// state 宣言型の高レベル API。
// describe/properties/commands を宣言するだけで AnyTestable を満たし、
// 手書き perform switch（旧②ブリッジ class）が不要になる。
//
// describedState の導出順: describe（明示 override）→ properties → Mirror フォールバック。
// perform は runTestablePerform に委譲する。
// `@MainActor final class` であるため Sendable / nonisolated perform witness は
// 既存の手書き実装（MyToggle 等）と同型で満たされる。

@MainActor
public final class TestableComponent<State>: ObservableObject, AnyTestable {
  public let testID: String
  @Published public var state: State

  private let describeOverride: ((State) -> [String: JSONValue])?
  private let properties: [String: TestableProperty<State>]
  private let commands: [String: (inout State, JSONValue) throws -> Void]

  public init(
    id: String,
    state: State,
    describe: ((State) -> [String: JSONValue])? = nil,
    properties: [String: TestableProperty<State>] = [:],
    commands: [String: (inout State, JSONValue) throws -> Void] = [:]
  ) {
    self.testID = id
    self.state = state
    self.describeOverride = describe
    self.properties = properties
    self.commands = commands
  }

  /// describe（明示）→ properties → Mirror の順で導出する
  private func describe(_ state: State) -> [String: JSONValue] {
    if let describeOverride {
      return describeOverride(state)
    }
    if !properties.isEmpty {
      var result: [String: JSONValue] = [:]
      for (key, property) in properties {
        result[key] = property.get(state)
      }
      return result
    }
    return mirrorDescribe(state)
  }

  public var describedState: [String: JSONValue] {
    describe(state)
  }

  public func perform(
    commandName: String,
    parameters: JSONValue
  ) async throws -> [String: JSONValue] {
    try runTestablePerform(
      commandName: commandName,
      parameters: parameters,
      state: &state,
      properties: properties,
      commands: commands,
      describe: describe
    )
  }
}
