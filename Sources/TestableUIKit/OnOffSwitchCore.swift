import Foundation

// MARK: - Shared State Struct

/// Pure value type holding OnOffSwitch state (for use with SwiftUI Views)
public struct OnOffSwitchState {
  public var isOn: Bool = false
  public var label: String = "Switch"
  public var isEnabled: Bool = true

  public init() {}
}

// MARK: - Pure Command Processing Functions

/// Pure function that produces a 3-key describedState
public func makeOnOffSwitchDescribedState(_ state: OnOffSwitchState) -> [String: JSONValue] {
  [
    "isOn": .bool(state.isOn),
    "label": .string(state.label),
    "isEnabled": .bool(state.isEnabled)
  ]
}

/// Handles the toggle command
/// - Semantics: no-op when isEnabled == false; toggles isOn when enabled
public func applyOnOffSwitchToggle(to state: inout OnOffSwitchState) {
  guard state.isEnabled else { return }
  state.isOn.toggle()
}

/// Handles the setProperty command (parameters: {"key": string, "value": <value>})
/// Supported keys: isOn (bool) / label (string) / isEnabled (bool)
public func applyOnOffSwitchSetProperty(
  to state: inout OnOffSwitchState,
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
  case "isOn":
    guard case .bool(let b) = value else { throw TestError.invalidParameters }
    state.isOn = b
  case "label":
    guard case .string(let s) = value else { throw TestError.invalidParameters }
    state.label = s
  case "isEnabled":
    guard case .bool(let enabled) = value else { throw TestError.invalidParameters }
    state.isEnabled = enabled
  default:
    throw TestError.unknownCommand("setProperty.\(key)")
  }
}
