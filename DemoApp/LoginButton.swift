import SwiftUI
import TestableUIKit

@MainActor
final class LoginButton: ObservableObject, AnyTestable {
  let testID: String = "scene.auth.loginButton"

  @Published var isEnabled: Bool = true   // 初期値 true（tap で false に変化）
  @Published var title: String = "Log In"

  var describedState: [String: JSONValue] {
    [
      "isEnabled": .bool(isEnabled),
      "title": .string(title)
    ]
  }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "tap":
      isEnabled = false
      return describedState
    case "setEnabled":
      if case .bool(let enabled) = parameters {
        isEnabled = enabled
      }
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}
