import SwiftUI
import TestableUIKit

// MARK: - TextInput（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class TextInput: ObservableObject, AnyTestable {
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

  var describedState: [String: JSONValue] {
    makeTextInputDescribedState(_state)
  }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "clear":
      var state = _state
      applyTextInputClear(to: &state)
      _state = state
      return describedState
    case "setProperty":
      var state = _state
      try applyTextInputSetProperty(to: &state, parameters: parameters)
      _state = state
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

// MARK: - TextInputView

struct TextInputView: View {
  @ObservedObject var textInput: TextInput

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

#Preview {
  TextInputView(textInput: TextInput())
}
