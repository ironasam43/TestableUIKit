import SwiftUI
import TestableUIKit

@MainActor
final class LoginButton: ObservableObject, AnyTestable {
  let testID: String = "scene.auth.loginButton"

  // @Published プロパティ（SwiftUI バインディング用）
  @Published var isEnabled: Bool = true   // 初期値 true（tap で false に変化）
  @Published var title: String = "Log In"
  @Published var isHidden: Bool = false
  @Published var alpha: Double = 1.0
  @Published var backgroundColor: String = "systemBlue"

  // LoginButtonState へのブリッジ（@Published ↔ struct の相互変換）
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

  var describedState: [String: JSONValue] {
    makeLoginButtonDescribedState(_state)
  }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "tap":
      var state = _state
      applyTap(to: &state)
      _state = state
      return describedState
    case "setProperty":
      var state = _state
      try applySetProperty(to: &state, parameters: parameters)
      _state = state
      return describedState
    case "setEnabled":
      var state = _state
      try applySetEnabled(to: &state, parameters: parameters)
      _state = state
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}
