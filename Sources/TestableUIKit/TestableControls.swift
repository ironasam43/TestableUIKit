import SwiftUI

// MARK: - BindingTestable（Tier 2 内部 bridge）
//
// SwiftUI の Binding 越しに値を read/write し、describe / commands を自動導出する
// 内部ブリッジ。各 Testable* コントロールが @StateObject で 1 つ生成し、
// 環境 registry へ自動登録する（TestableView / TestableEnvironment の登録パターンを踏襲）。
//
// `@MainActor final class` であるため Sendable / nonisolated perform witness を満たす。

@available(iOS 15.0, macOS 13.0, *)
@MainActor
final class BindingTestable<Value>: ObservableObject, AnyTestable {
  let testID: String
  private let read: () -> Value
  private let write: (Value) -> Void
  private let toJSON: (Value) -> JSONValue
  private let fromJSON: (JSONValue) throws -> Value
  /// 値型コマンド名 → 現在値に対する変換（toggle / increment など）
  private let commands: [String: (Value) -> Value]
  /// 副作用コマンド名（Button の tap など。値を持たない）
  private let actions: [String: () -> Void]

  /// describe 時のキー名（"isOn" / "value" / "text" 等）
  private let valueKey: String

  init(
    id: String,
    valueKey: String,
    binding: Binding<Value>,
    toJSON: @escaping (Value) -> JSONValue,
    fromJSON: @escaping (JSONValue) throws -> Value,
    commands: [String: (Value) -> Value] = [:],
    actions: [String: () -> Void] = [:]
  ) {
    self.testID = id
    self.valueKey = valueKey
    self.read = { binding.wrappedValue }
    self.write = { binding.wrappedValue = $0 }
    self.toJSON = toJSON
    self.fromJSON = fromJSON
    self.commands = commands
    self.actions = actions
  }

  var describedState: [String: JSONValue] {
    [valueKey: toJSON(read())]
  }

  func perform(
    commandName: String,
    parameters: JSONValue
  ) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "setProperty":
      guard case .object(let dict) = parameters,
            case .string(let key) = dict["key"],
            let value = dict["value"], key == valueKey else {
        throw TestError.invalidParameters
      }
      write(try fromJSON(value))
      return describedState
    default:
      if let action = actions[commandName] {
        action()
        return describedState
      }
      if let transform = commands[commandName] {
        write(transform(read()))
        return describedState
      }
      throw TestError.unknownCommand(commandName)
    }
  }
}

// MARK: - JSONValue 変換ヘルパ

@available(iOS 15.0, macOS 13.0, *)
private func boolFromJSON(_ value: JSONValue) throws -> Bool {
  guard case .bool(let b) = value else { throw TestError.invalidParameters }
  return b
}

@available(iOS 15.0, macOS 13.0, *)
private func stringFromJSON(_ value: JSONValue) throws -> String {
  guard case .string(let s) = value else { throw TestError.invalidParameters }
  return s
}

@available(iOS 15.0, macOS 13.0, *)
private func intFromJSON(_ value: JSONValue) throws -> Int {
  guard case .int(let n) = value else { throw TestError.invalidParameters }
  return n
}

@available(iOS 15.0, macOS 13.0, *)
private func doubleFromJSON(_ value: JSONValue) throws -> Double {
  switch value {
  case .double(let d): return d
  case .int(let n): return Double(n)
  default: throw TestError.invalidParameters
  }
}

// MARK: - TestableToggle
//
// コマンド表: toggle / setProperty。describe キー = "isOn"。

@available(iOS 15.0, macOS 13.0, *)
public struct TestableToggle: View {
  private let title: String
  private let isOn: Binding<Bool>
  @StateObject private var bridge: BindingTestable<Bool>

  public init(_ title: String, isOn: Binding<Bool>, id: String) {
    self.title = title
    self.isOn = isOn
    _bridge = StateObject(wrappedValue: BindingTestable(
      id: id,
      valueKey: "isOn",
      binding: isOn,
      toJSON: { .bool($0) },
      fromJSON: boolFromJSON,
      commands: ["toggle": { !$0 }]
    ))
  }

  public var body: some View {
    Toggle(title, isOn: isOn)
      .testable(bridge)
  }
}

// MARK: - TestableTextField
//
// コマンド表: setProperty。describe キー = "text"。

@available(iOS 15.0, macOS 13.0, *)
public struct TestableTextField: View {
  private let title: String
  private let text: Binding<String>
  @StateObject private var bridge: BindingTestable<String>

  public init(_ title: String, text: Binding<String>, id: String) {
    self.title = title
    self.text = text
    _bridge = StateObject(wrappedValue: BindingTestable(
      id: id,
      valueKey: "text",
      binding: text,
      toJSON: { .string($0) },
      fromJSON: stringFromJSON
    ))
  }

  public var body: some View {
    TextField(title, text: text)
      .testable(bridge)
  }
}

// MARK: - TestableStepper
//
// コマンド表: increment / decrement / setProperty。describe キー = "value"。

@available(iOS 15.0, macOS 13.0, *)
public struct TestableStepper: View {
  private let title: String
  private let value: Binding<Int>
  @StateObject private var bridge: BindingTestable<Int>

  public init(_ title: String, value: Binding<Int>, id: String) {
    self.title = title
    self.value = value
    _bridge = StateObject(wrappedValue: BindingTestable(
      id: id,
      valueKey: "value",
      binding: value,
      toJSON: { .int($0) },
      fromJSON: intFromJSON,
      commands: [
        "increment": { $0 + 1 },
        "decrement": { $0 - 1 }
      ]
    ))
  }

  public var body: some View {
    Stepper(title, value: value)
      .testable(bridge)
  }
}

// MARK: - TestableSlider
//
// コマンド表: setProperty。describe キー = "value"。

@available(iOS 15.0, macOS 13.0, *)
public struct TestableSlider: View {
  private let value: Binding<Double>
  private let range: ClosedRange<Double>
  @StateObject private var bridge: BindingTestable<Double>

  public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1, id: String) {
    self.value = value
    self.range = range
    _bridge = StateObject(wrappedValue: BindingTestable(
      id: id,
      valueKey: "value",
      binding: value,
      toJSON: { .double($0) },
      fromJSON: doubleFromJSON
    ))
  }

  public var body: some View {
    Slider(value: value, in: range)
      .testable(bridge)
  }
}

// MARK: - TestableButton
//
// コマンド表: tap（副作用のみ・値なし）。describe キー = "tapCount"。

@available(iOS 15.0, macOS 13.0, *)
public struct TestableButton: View {
  private let title: String
  private let action: () -> Void
  @StateObject private var bridge: BindingTestable<Int>
  @State private var tapCount: Int = 0

  public init(_ title: String, id: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
    // tapCount を内部状態として保持し、tap コマンドで action 実行＋カウントを増やす。
    let countBox = TapCountBox()
    _bridge = StateObject(wrappedValue: BindingTestable<Int>(
      id: id,
      valueKey: "tapCount",
      binding: Binding(
        get: { countBox.count },
        set: { countBox.count = $0 }
      ),
      toJSON: { .int($0) },
      fromJSON: intFromJSON,
      actions: ["tap": {
        countBox.count += 1
        action()
      }]
    ))
  }

  public var body: some View {
    Button(title) {
      // UI からのタップも tapCount に反映する
      Task { _ = try? await bridge.perform(commandName: "tap", parameters: .null) }
    }
  }
}

// MARK: - TapCountBox
//
// TestableButton の tapCount を保持する参照型ボックス。
// init 内で Binding を組むために値の所有者が必要。

@available(iOS 15.0, macOS 13.0, *)
@MainActor
private final class TapCountBox {
  var count: Int = 0
}
