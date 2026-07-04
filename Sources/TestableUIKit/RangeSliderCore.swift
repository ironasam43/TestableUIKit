import Foundation

// MARK: - Shared State Struct

/// Pure value type holding RangeSlider state (for use with SwiftUI Views)
public struct RangeSliderState {
  public var value: Double = 50.0
  public var minValue: Double = 0.0
  public var maxValue: Double = 100.0
  public var step: Double = 1.0

  public init() {}
}

// MARK: - Pure Command Processing Functions

/// Pure function that produces a 4-key describedState
public func makeRangeSliderDescribedState(_ state: RangeSliderState) -> [String: JSONValue] {
  [
    "value": .double(state.value),
    "minValue": .double(state.minValue),
    "maxValue": .double(state.maxValue),
    "step": .double(state.step)
  ]
}

/// Handles the reset command
/// - Semantics: resets value to the midpoint: (maxValue - minValue) / 2 + minValue
public func applyRangeSliderReset(to state: inout RangeSliderState) {
  state.value = (state.maxValue - state.minValue) / 2 + state.minValue
}

/// Handles the setProperty command (parameters: {"key": string, "value": <value>})
/// Supported keys: value (double) / minValue (double) / maxValue (double) / step (double)
public func applyRangeSliderSetProperty(
  to state: inout RangeSliderState,
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
  case "value":
    guard case .double(let d) = value else { throw TestError.invalidParameters }
    state.value = d
  case "minValue":
    guard case .double(let d) = value else { throw TestError.invalidParameters }
    state.minValue = d
  case "maxValue":
    guard case .double(let d) = value else { throw TestError.invalidParameters }
    state.maxValue = d
  case "step":
    guard case .double(let d) = value else { throw TestError.invalidParameters }
    state.step = d
  default:
    throw TestError.unknownCommand("setProperty.\(key)")
  }
}
