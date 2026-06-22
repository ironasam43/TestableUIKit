import Foundation

// MARK: - 共有状態 struct

/// OnOffSwitch の状態を保持する純粋な値型（SwiftUI View 用）
public struct OnOffSwitchState {
  public var isOn: Bool = false
  public var label: String = "Switch"
  public var isEnabled: Bool = true

  public init() {}
}

// MARK: - 純粋コマンド処理関数

/// 3キー describedState を生成する純粋関数
public func makeOnOffSwitchDescribedState(_ state: OnOffSwitchState) -> [String: JSONValue] {
  [
    "isOn": .bool(state.isOn),
    "label": .string(state.label),
    "isEnabled": .bool(state.isEnabled)
  ]
}

/// toggle コマンド処理
/// - 意味論: isEnabled == false なら no-op。有効時は isOn を反転する。
public func applyOnOffSwitchToggle(to state: inout OnOffSwitchState) {
  guard state.isEnabled else { return }
  state.isOn.toggle()
}

/// setProperty コマンド処理（parameters: {"key": string, "value": <value>}）
/// サポートキー: isOn（bool）/ label（string）/ isEnabled（bool）
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
