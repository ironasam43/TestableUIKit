import Foundation

// MARK: - 共有状態 struct

/// Counter の状態を保持する純粋な値型（SwiftUI View 用）
public struct CounterState {
  public var count: Int = 0
  public var isEnabled: Bool = true

  public init() {}
}

// MARK: - 純粋コマンド処理関数

/// 2キー describedState を生成する純粋関数
public func makeCounterDescribedState(_ state: CounterState) -> [String: JSONValue] {
  [
    "count": .int(state.count),
    "isEnabled": .bool(state.isEnabled)
  ]
}

/// increment コマンド処理
/// - 意味論: isEnabled == false なら no-op。有効時は count を 1 加算する。
public func applyIncrement(to state: inout CounterState) {
  guard state.isEnabled else { return }
  state.count += 1
}

/// decrement コマンド処理
/// - 意味論: isEnabled == false なら no-op。有効時は count を 1 減算する（負の値も可）。
public func applyDecrement(to state: inout CounterState) {
  guard state.isEnabled else { return }
  state.count -= 1
}

/// reset コマンド処理
/// - 意味論: isEnabled に関わらず count を 0 にリセットする。
public func applyCounterReset(to state: inout CounterState) {
  state.count = 0
}

/// setProperty コマンド処理（parameters: {"key": string, "value": <value>}）
/// サポートキー: count（int）/ isEnabled（bool）
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
