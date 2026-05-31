import Foundation
import TestableUIKit

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
    switch commandName {
    case "tap":
      lock.withLock {
        _isEnabled = false
      }
    default:
      throw TestError.unknownCommand(commandName)
    }
    return describedState
  }
}
