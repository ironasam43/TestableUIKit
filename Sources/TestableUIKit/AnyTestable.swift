import Foundation

// MARK: - Protocol

public protocol AnyTestable: AnyObject, Sendable {
  var testID: String { get }
  var describedState: [String: JSONValue] { get }
  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue]
}

// MARK: - TestableRegistry

public actor TestableRegistry {
  private var testables: [String: AnyTestable] = [:]

  public init() {}

  public func register(_ testable: AnyTestable) {
    testables[testable.testID] = testable
  }

  public func find(id testID: String) -> AnyTestable? {
    testables[testID]
  }
}

// MARK: - Error

public enum TestError: Error {
  case unknownCommand(String)
  case componentNotFound(String)
  case invalidParameters
}
