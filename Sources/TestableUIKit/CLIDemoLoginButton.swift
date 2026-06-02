import Foundation

public final class CLIDemoLoginButton: AnyTestable, @unchecked Sendable {
  public let testID = "scene.auth.loginButton"
  private var _state = LoginButtonState()
  private let lock = NSLock()

  public var isEnabled: Bool {
    lock.withLock { _state.isEnabled }
  }

  public var title: String {
    lock.withLock { _state.title }
  }

  public var describedState: [String: JSONValue] {
    lock.withLock { makeLoginButtonDescribedState(_state) }
  }

  public init() {}

  public func perform(
    commandName: String,
    parameters: JSONValue
  ) async throws -> [String: JSONValue] {
    // Debug logging
    print("[DEBUG] perform: commandName=\(commandName), parameters=\(parameters)")

    switch commandName {
    case "getState":
      return describedState

    case "tap":
      lock.withLock { applyTap(to: &_state) }

    case "setProperty":
      if case .object(let dict) = parameters {
        print("[DEBUG] setProperty: dict keys = \(dict.keys)")
        print("[DEBUG] setProperty: key=\(dict["key"] ?? .null)")
        print("[DEBUG] setProperty: value=\(dict["value"] ?? .null)")
      } else {
        print("[DEBUG] setProperty: parameters is not an object: \(parameters)")
      }
      var snapshot = lock.withLock { _state }
      try applySetProperty(to: &snapshot, parameters: parameters)
      lock.withLock { _state = snapshot }

    case "setEnabled":
      var snapshot = lock.withLock { _state }
      try applySetEnabled(to: &snapshot, parameters: parameters)
      lock.withLock { _state = snapshot }

    default:
      throw TestError.unknownCommand(commandName)
    }
    return describedState
  }
}
