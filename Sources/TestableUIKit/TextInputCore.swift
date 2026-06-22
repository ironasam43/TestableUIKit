import Foundation

// MARK: - 共有状態 struct

/// TextInput の状態を保持する純粋な値型（SwiftUI View 用）
public struct TextInputState {
  public var text: String = ""
  public var placeholder: String = "Enter text"
  public var isEnabled: Bool = true

  public init() {}
}

// MARK: - 純粋コマンド処理関数

/// 3キー describedState を生成する純粋関数
public func makeTextInputDescribedState(_ state: TextInputState) -> [String: JSONValue] {
  [
    "text": .string(state.text),
    "placeholder": .string(state.placeholder),
    "isEnabled": .bool(state.isEnabled)
  ]
}

/// clear コマンド処理
/// - 意味論: isEnabled == false なら no-op。有効時は text を空にする。
public func applyTextInputClear(to state: inout TextInputState) {
  guard state.isEnabled else { return }
  state.text = ""
}

/// setProperty コマンド処理（parameters: {"key": string, "value": <value>}）
/// サポートキー: text（string）/ placeholder（string）/ isEnabled（bool）
public func applyTextInputSetProperty(
  to state: inout TextInputState,
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
  case "text":
    guard case .string(let s) = value else { throw TestError.invalidParameters }
    state.text = s
  case "placeholder":
    guard case .string(let s) = value else { throw TestError.invalidParameters }
    state.placeholder = s
  case "isEnabled":
    guard case .bool(let enabled) = value else { throw TestError.invalidParameters }
    state.isEnabled = enabled
  default:
    throw TestError.unknownCommand("setProperty.\(key)")
  }
}
