import SwiftUI
import TestableUIKit

// MARK: - OnOffSwitch（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class OnOffSwitch: ObservableObject, AnyTestable {
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

  var describedState: [String: JSONValue] {
    makeOnOffSwitchDescribedState(_state)
  }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "toggle":
      var state = _state
      applyOnOffSwitchToggle(to: &state)
      _state = state
      return describedState
    case "setProperty":
      var state = _state
      try applyOnOffSwitchSetProperty(to: &state, parameters: parameters)
      _state = state
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

// MARK: - OnOffSwitchView

struct OnOffSwitchView: View {
  @ObservedObject var onOffSwitch: OnOffSwitch

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

#Preview {
  OnOffSwitchView(onOffSwitch: OnOffSwitch())
}
