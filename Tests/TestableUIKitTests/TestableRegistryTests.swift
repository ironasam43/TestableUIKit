import XCTest
@testable import TestableUIKit

// MARK: - Minimal AnyTestable implementation for tests

private final class MockTestable: AnyTestable, @unchecked Sendable {
  let testID: String

  init(testID: String) {
    self.testID = testID
  }

  var describedState: [String: JSONValue] { ["stub": .bool(true)] }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    return describedState
  }
}

// MARK: - TestableRegistry Tests

final class TestableRegistryTests: XCTestCase {

  // register → find round-trip: a registered testable must be retrievable by testID
  func testRegisterAndFind() async throws {
    let registry = TestableRegistry()
    let id = "test.registry.roundtrip"
    let mock = MockTestable(testID: id)

    await registry.register(mock)
    let found = await registry.find(id: id)

    XCTAssertNotNil(found, "A registered testable must be retrievable via find")
    XCTAssertEqual(found?.testID, id, "The testID of the retrieved testable must match")
  }

  // An unregistered ID must return nil
  func testFindUnregisteredReturnsNil() async throws {
    let registry = TestableRegistry()
    let id = "test.registry.nonexistent.\(UUID().uuidString)"
    let found = await registry.find(id: id)

    XCTAssertNil(found, "An unregistered testID must return nil")
  }

  // Re-registering the same ID must overwrite with the new instance
  func testReregisterOverwrites() async throws {
    let registry = TestableRegistry()
    let id = "test.registry.overwrite"
    let first = MockTestable(testID: id)
    let second = MockTestable(testID: id)

    await registry.register(first)
    await registry.register(second)
    let found = await registry.find(id: id)

    XCTAssertNotNil(found, "find must succeed after re-registration")
    XCTAssertTrue(found === second, "Re-registration must overwrite with the new instance")
  }

  // describedState must be retrievable (basic AnyTestable contract)
  func testDescribedState() async throws {
    let registry = TestableRegistry()
    let id = "test.registry.state"
    let mock = MockTestable(testID: id)

    await registry.register(mock)
    let found = await registry.find(id: id)

    XCTAssertEqual(found?.describedState["stub"], .bool(true), "describedState must match the expected value")
  }

  // Proof that the singleton is removed: multiple instances must be isolated from each other
  func testMultipleInstancesAreIsolated() async throws {
    let registryA = TestableRegistry()
    let registryB = TestableRegistry()
    let id = "test.registry.isolation"
    let mock = MockTestable(testID: id)

    await registryA.register(mock)

    let foundInA = await registryA.find(id: id)
    let foundInB = await registryB.find(id: id)

    XCTAssertNotNil(foundInA, "A testable registered in registryA must be retrievable from registryA")
    XCTAssertNil(foundInB, "A testable registered in registryA must not be retrievable from registryB (instance isolation)")
  }
}
