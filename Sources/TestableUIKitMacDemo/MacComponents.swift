#if os(macOS)
import SwiftUI
import TestableUIKit

// MARK: - MacCounter（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class MacCounter: ObservableObject, AnyTestable {
  let testID: String = "scene.demo.counter"

  @Published var count: Int = 0
  @Published var isEnabled: Bool = true

  private var _state: CounterState {
    get {
      var s = CounterState()
      s.count = count
      s.isEnabled = isEnabled
      return s
    }
    set {
      count = newValue.count
      isEnabled = newValue.isEnabled
    }
  }

  var describedState: [String: JSONValue] { makeCounterDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "increment":
      var s = _state; applyIncrement(to: &s); _state = s; return describedState
    case "decrement":
      var s = _state; applyDecrement(to: &s); _state = s; return describedState
    case "reset":
      var s = _state; applyCounterReset(to: &s); _state = s; return describedState
    case "setProperty":
      var s = _state
      try applyCounterSetProperty(to: &s, parameters: parameters)
      _state = s
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

struct MacCounterView: View {
  @ObservedObject var counter: MacCounter

  var body: some View {
    VStack(spacing: 10) {
      Text("Counter: \(counter.count)")
        .font(.headline)

      HStack(spacing: 20) {
        Button("-") {
          Task { @MainActor in
            _ = try? await counter.perform(commandName: "decrement", parameters: .null)
          }
        }
        .frame(width: 44, height: 44)
        .background(counter.isEnabled ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(!counter.isEnabled)

        Button("+") {
          Task { @MainActor in
            _ = try? await counter.perform(commandName: "increment", parameters: .null)
          }
        }
        .frame(width: 44, height: 44)
        .background(counter.isEnabled ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(!counter.isEnabled)
      }

      Text("testID: \(counter.testID)")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(8)
  }
}

// MARK: - MacLoginButton（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class MacLoginButton: ObservableObject, AnyTestable {
  let testID: String = "scene.auth.loginButton"

  @Published var isEnabled: Bool = true
  @Published var title: String = "Log In"
  @Published var isHidden: Bool = false
  @Published var alpha: Double = 1.0
  @Published var backgroundColor: String = "systemBlue"

  private var _state: LoginButtonState {
    get {
      var s = LoginButtonState()
      s.isEnabled = isEnabled
      s.title = title
      s.isHidden = isHidden
      s.alpha = alpha
      s.backgroundColor = backgroundColor
      return s
    }
    set {
      isEnabled = newValue.isEnabled
      title = newValue.title
      isHidden = newValue.isHidden
      alpha = newValue.alpha
      backgroundColor = newValue.backgroundColor
    }
  }

  var describedState: [String: JSONValue] { makeLoginButtonDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "tap":
      var s = _state; applyTap(to: &s); _state = s; return describedState
    case "setProperty":
      var s = _state
      try applySetProperty(to: &s, parameters: parameters)
      _state = s
      return describedState
    case "setEnabled":
      var s = _state
      try applySetEnabled(to: &s, parameters: parameters)
      _state = s
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

// MARK: - MacTextInput（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class MacTextInput: ObservableObject, AnyTestable {
  let testID: String = "scene.demo.textInput"

  @Published var text: String = ""
  @Published var placeholder: String = "Enter text"
  @Published var isEnabled: Bool = true

  private var _state: TextInputState {
    get {
      var s = TextInputState()
      s.text = text
      s.placeholder = placeholder
      s.isEnabled = isEnabled
      return s
    }
    set {
      text = newValue.text
      placeholder = newValue.placeholder
      isEnabled = newValue.isEnabled
    }
  }

  var describedState: [String: JSONValue] { makeTextInputDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "clear":
      var s = _state; applyTextInputClear(to: &s); _state = s; return describedState
    case "setProperty":
      var s = _state
      try applyTextInputSetProperty(to: &s, parameters: parameters)
      _state = s
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

struct MacTextInputView: View {
  @ObservedObject var textInput: MacTextInput

  var body: some View {
    VStack(spacing: 10) {
      TextField(textInput.placeholder, text: $textInput.text)
        .textFieldStyle(.roundedBorder)
        .disabled(!textInput.isEnabled)

      Button("Clear") {
        Task { @MainActor in
          _ = try? await textInput.perform(commandName: "clear", parameters: .null)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(textInput.isEnabled ? Color.blue : Color.gray)
      .foregroundColor(.white)
      .cornerRadius(8)
      .disabled(!textInput.isEnabled)
    }
    .padding()
  }
}

// MARK: - MacOnOffSwitch（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class MacOnOffSwitch: ObservableObject, AnyTestable {
  let testID: String = "scene.demo.onOffSwitch"

  @Published var isOn: Bool = false
  @Published var label: String = "Switch"
  @Published var isEnabled: Bool = true

  private var _state: OnOffSwitchState {
    get {
      var s = OnOffSwitchState()
      s.isOn = isOn
      s.label = label
      s.isEnabled = isEnabled
      return s
    }
    set {
      isOn = newValue.isOn
      label = newValue.label
      isEnabled = newValue.isEnabled
    }
  }

  var describedState: [String: JSONValue] { makeOnOffSwitchDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "toggle":
      var s = _state; applyOnOffSwitchToggle(to: &s); _state = s; return describedState
    case "setProperty":
      var s = _state
      try applyOnOffSwitchSetProperty(to: &s, parameters: parameters)
      _state = s
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

struct MacOnOffSwitchView: View {
  @ObservedObject var onOffSwitch: MacOnOffSwitch

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text(onOffSwitch.label)
          .font(.headline)
        Spacer()
        Toggle("", isOn: $onOffSwitch.isOn)
          .disabled(!onOffSwitch.isEnabled)
      }
      .padding()
    }
  }
}

// MARK: - MacRangeSlider（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class MacRangeSlider: ObservableObject, AnyTestable {
  let testID: String = "scene.demo.rangeSlider"

  @Published var value: Double = 50.0
  @Published var minValue: Double = 0.0
  @Published var maxValue: Double = 100.0
  @Published var step: Double = 1.0
  @Published var isEnabled: Bool = true

  private var _state: RangeSliderState {
    get {
      var s = RangeSliderState()
      s.value = value
      s.minValue = minValue
      s.maxValue = maxValue
      s.step = step
      return s
    }
    set {
      value = newValue.value
      minValue = newValue.minValue
      maxValue = newValue.maxValue
      step = newValue.step
    }
  }

  var describedState: [String: JSONValue] { makeRangeSliderDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "reset":
      var s = _state; applyRangeSliderReset(to: &s); _state = s; return describedState
    case "setProperty":
      var s = _state
      try applyRangeSliderSetProperty(to: &s, parameters: parameters)
      _state = s
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

struct MacRangeSliderView: View {
  @ObservedObject var rangeSlider: MacRangeSlider

  var body: some View {
    VStack(spacing: 15) {
      Text("Value: \(String(format: "%.1f", rangeSlider.value))")
        .font(.headline)

      Slider(
        value: $rangeSlider.value,
        in: rangeSlider.minValue...rangeSlider.maxValue,
        step: rangeSlider.step
      )
      .disabled(!rangeSlider.isEnabled)

      Button("Reset") {
        Task { @MainActor in
          _ = try? await rangeSlider.perform(commandName: "reset", parameters: .null)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(rangeSlider.isEnabled ? Color.blue : Color.gray)
      .foregroundColor(.white)
      .cornerRadius(8)
      .disabled(!rangeSlider.isEnabled)
    }
    .padding()
  }
}

#endif // os(macOS)
