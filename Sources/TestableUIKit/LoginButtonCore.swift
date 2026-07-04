import Foundation

// MARK: - Shared State Struct

/// Pure value type holding LoginButton state (shared by CLI and SwiftUI)
public struct LoginButtonState {
  public var isEnabled: Bool = true
  public var title: String = "Log In"
  public var isHidden: Bool = false
  public var alpha: Double = 1.0
  public var backgroundColor: String = "systemBlue"

  public init() {}
}

// MARK: - Pure Command Processing Functions

/// Pure function that produces a 5-key describedState
public func makeLoginButtonDescribedState(_ state: LoginButtonState) -> [String: JSONValue] {
  [
    "isEnabled": .bool(state.isEnabled),
    "title": .string(state.title),
    "isHidden": .bool(state.isHidden),
    "alpha": .double(state.alpha),
    "backgroundColor": .string(state.backgroundColor)
  ]
}

/// Handles the tap command
/// - Semantics: rejects tap when disabled (no-op), mirroring real-user behavior; simulates a login transition when enabled
/// - Side effects: guard isEnabled / isEnabled = false (prevent double-submit) / title = "Logged In"
public func applyTap(to state: inout LoginButtonState) {
  guard state.isEnabled else { return }  // no-op when disabled (mirrors real-user behavior)
  state.isEnabled = false                 // prevent double-submit
  state.title = "Logged In"              // visible login result (proof of @Published re-render)
}

/// Handles the setProperty command (parameters: {"key": string, "value": <value>})
public func applySetProperty(
  to state: inout LoginButtonState,
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
  case "isEnabled":
    guard case .bool(let enabled) = value else { throw TestError.invalidParameters }
    state.isEnabled = enabled
  case "title":
    guard case .string(let text) = value else { throw TestError.invalidParameters }
    state.title = text
  case "isHidden":
    guard case .bool(let hidden) = value else { throw TestError.invalidParameters }
    state.isHidden = hidden
  case "alpha":
    guard case .double(let alphaValue) = value else { throw TestError.invalidParameters }
    state.alpha = alphaValue
  case "backgroundColor":
    guard case .string(let color) = value else { throw TestError.invalidParameters }
    state.backgroundColor = color
  default:
    throw TestError.unknownCommand("setProperty.\(key)")
  }
}

/// Handles the setEnabled command (parameters: JSONValue.bool)
public func applySetEnabled(
  to state: inout LoginButtonState,
  parameters: JSONValue
) throws {
  guard case .bool(let enabled) = parameters else {
    throw TestError.invalidParameters
  }
  state.isEnabled = enabled
}
