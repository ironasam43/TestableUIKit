import Foundation

// MARK: - 共有状態 struct

/// LoginButton の状態を保持する純粋な値型（CLI・SwiftUI 共用）
public struct LoginButtonState {
  public var isEnabled: Bool = true
  public var title: String = "Log In"
  public var isHidden: Bool = false
  public var alpha: Double = 1.0
  public var backgroundColor: String = "systemBlue"

  public init() {}
}

// MARK: - 純粋コマンド処理関数

/// 5キー describedState を生成する純粋関数
public func makeLoginButtonDescribedState(_ state: LoginButtonState) -> [String: JSONValue] {
  [
    "isEnabled": .bool(state.isEnabled),
    "title": .string(state.title),
    "isHidden": .bool(state.isHidden),
    "alpha": .double(state.alpha),
    "backgroundColor": .string(state.backgroundColor)
  ]
}

/// tap コマンド処理
/// - 意味論: 実ユーザー同様に disabled は弾く（no-op）。有効時はログイン遷移を模倣。
/// - 副作用: guard isEnabled / isEnabled = false（二重送信防止）/ title = "Logged In"
public func applyTap(to state: inout LoginButtonState) {
  guard state.isEnabled else { return }  // 無効なら no-op（実ユーザー同様に弾く）
  state.isEnabled = false                 // 二重送信防止
  state.title = "Logged In"              // 可視なログイン結果（@Published 再描画の証拠）
}

/// setProperty コマンド処理（parameters: {"key": string, "value": <value>}）
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

/// setEnabled コマンド処理（parameters: JSONValue.bool）
public func applySetEnabled(
  to state: inout LoginButtonState,
  parameters: JSONValue
) throws {
  guard case .bool(let enabled) = parameters else {
    throw TestError.invalidParameters
  }
  state.isEnabled = enabled
}
