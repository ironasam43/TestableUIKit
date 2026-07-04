import Foundation

// MARK: - Shared State Struct

/// Pure value type holding Counter state (for use with SwiftUI Views)
public struct CounterState {
  public var count: Int = 0
  public var isEnabled: Bool = true

  public init() {}
}

// MARK: - Pure Command Processing Functions

/// Pure function that produces a 2-key describedState
public func makeCounterDescribedState(_ state: CounterState) -> [String: JSONValue] {
  [
    "count": .int(state.count),
    "isEnabled": .bool(state.isEnabled)
  ]
}

/// Handles the increment command
/// - Semantics: no-op when isEnabled == false; increments count by 1 when enabled
public func applyIncrement(to state: inout CounterState) {
  guard state.isEnabled else { return }
  state.count += 1
}

/// Handles the decrement command
/// - Semantics: no-op when isEnabled == false; decrements count by 1 when enabled (negative values allowed)
public func applyDecrement(to state: inout CounterState) {
  guard state.isEnabled else { return }
  state.count -= 1
}

/// Handles the reset command
/// - Semantics: resets count to 0 regardless of isEnabled
public func applyCounterReset(to state: inout CounterState) {
  state.count = 0
}

/// Handles the setProperty command (parameters: {"key": string, "value": <value>})
/// Supported keys: count (int) / isEnabled (bool)
public func applyCounterSetProperty(
  to state: inout CounterState,
  parameters: JSONValue
) throws {
  guard case .object(let dict) = parameters else {
    throw TestError.invalidParameters
  }
  guard case .string(let key) = dict["key"] else {
    throw TestError.invalidParameters
  }
  guard let value = dict["value"] else {
    throw TestError.invalidParameters
  }
  switch key {
  case "count":
    guard case .int(let n) = value else { throw TestError.invalidParameters }
    state.count = n
  case "isEnabled":
    guard case .bool(let enabled) = value else { throw TestError.invalidParameters }
    state.isEnabled = enabled
  default:
    throw TestError.unknownCommand("setProperty.\(key)")
  }
}
