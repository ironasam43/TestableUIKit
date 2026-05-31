import Foundation

public final class CLIDemoLoginButton: AnyTestable, @unchecked Sendable {
  public let testID = "scene.auth.loginButton"
  private var _isEnabled = true
  private var _title = "Log In"

  private let lock = NSLock()

  public var isEnabled: Bool {
    lock.withLock { _isEnabled }
  }

  public var title: String {
    lock.withLock { _title }
  }

  public var describedState: [String: JSONValue] {
    lock.withLock {
      [
        "isEnabled": .bool(_isEnabled),
        "title": .string(_title)
      ]
    }
  }

  public init() {}

  public func perform(
    commandName: String,
    parameters: JSONValue
  ) async throws -> [String: JSONValue] {
    // Debug logging
    print("[DEBUG] perform: commandName=\(commandName), parameters=\(parameters)")

    switch commandName {
    case "tap":
      lock.withLock {
        _isEnabled = false
      }
    case "setProperty":
      guard case .object(let dict) = parameters else {
        print("[DEBUG] setProperty: parameters is not an object: \(parameters)")
        throw TestError.invalidParameters
      }
      print("[DEBUG] setProperty: dict keys = \(dict.keys)")
      guard case .string(let key) = dict["key"] else {
        print("[DEBUG] setProperty: dict['key'] is not a string: \(dict["key"] ?? .null)")
        throw TestError.invalidParameters
      }
      print("[DEBUG] setProperty: key=\(key)")
      guard let value = dict["value"] else {
        print("[DEBUG] setProperty: dict['value'] is nil")
        throw TestError.invalidParameters
      }
      print("[DEBUG] setProperty: value=\(value)")

      switch key {
      case "isEnabled":
        guard case .bool(let enabled) = value else {
          throw TestError.invalidParameters
        }
        lock.withLock { _isEnabled = enabled }
      case "title":
        guard case .string(let text) = value else {
          throw TestError.invalidParameters
        }
        lock.withLock { _title = text }
      default:
        throw TestError.unknownCommand("setProperty.\(key)")
      }
    default:
      throw TestError.unknownCommand(commandName)
    }
    return describedState
  }
}
