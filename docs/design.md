# TestableUIKit Design & Architecture

## Overview

TestableUIKit is a framework for automating iOS UI testing via HTTP-based IPC protocol.

### Core Concept

- **Framework**: `TestableUIKit.framework` — IPC infrastructure (TestableServer, AnyTestable protocol, JSONValue encoding)
- **Demo App**: `DemoApp` — Reference implementation showing how to instrument SwiftUI components
- **Network Layer**: HTTP over localhost:8888 (no cloud/external dependencies)

---

## Architecture Layers

### 1. Protocol Layer (`AnyTestable`)

Each UI component that participates in testing must conform to `AnyTestable`:

```swift
protocol AnyTestable: Actor {
  var testID: String { get }
  var describedState: [String: JSONValue] { get }
  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue]
}
```

**Responsibilities**:
- Identify itself via unique `testID`
- Expose state snapshot via `describedState`
- Execute commands and return resulting state

### 2. Server Layer (`TestableServer`)

HTTP REST server listening on localhost:8888:

- `GET /ping` — connectivity check
- `POST /perform` — execute command on component

See `docs/ipc-protocol.md` for endpoint specifications.

### 3. Registry (`TestableRegistry`)

Central store for all `AnyTestable` components, keyed by testID.

```swift
@MainActor
final class TestableRegistry {
  static let shared = TestableRegistry()
  func register(_ testable: AnyTestable)
  func find(id: String) -> AnyTestable?
}
```

**Registration happens at runtime** when components are instantiated (typically in SwiftUI `.onAppear()`).

---

## Project Structure

```
TestableUIKit/
├── Sources/
│   ├── TestableUIKit/                 # Framework target
│   │   ├── AnyTestable.swift         # Protocol definition
│   │   ├── JSONValue.swift           # Wire format enum
│   │   ├── TestableServer.swift      # HTTP server + PerformRequest
│   │   └── (implicit TestableRegistry, TestError from AnyTestable.swift)
│   └── (no LoginButton here)
├── DemoApp/
│   ├── DemoApp.swift                 # App entry point
│   ├── LoginButton.swift             # Reference component (AnyTestable impl)
│   └── Info.plist
├── TestableUIKitDemo.xcodeproj/      # Single xcodeproj for both targets
├── docs/
│   ├── design.md                     # This file
│   ├── ipc-protocol.md               # HTTP API spec
│   └── [future: ci-integration.md, troubleshooting.md]
└── run_test.py                       # Test runner script (Python)
```

---

## Component Registration Flow

1. **App Launch**: `DemoApp` runs, SwiftUI renders
2. **View Hierarchy**: `LoginButton` view is instantiated
3. **Registration**: `.onAppear()` hook calls `TestableRegistry.shared.register(loginButton)`
4. **Server Readiness**: After first registration, TestableServer is fully operational
5. **Test Execution**: run_test.py sends POST /perform with testID → LoginButton responds

---

## State Change Semantics

### getState (Query)

Returns current state **without side effects**.

```swift
case "getState":
  return describedState
```

### tap (Action)

Executes action and returns resulting state.

```swift
case "tap":
  isEnabled = false    // side effect
  return describedState
```

**Key principle**: All commands return state in the same `[String: JSONValue]` format for consistency.

---

## Testing Philosophy

### Phase A: Network Path Verification

Ensures Simulator ↔ Host communication is working:
```bash
GET /ping → {"status": "ok"}
```

### Phase B: Logic Verification

Ensures UI state responds to commands:
```bash
POST /perform { testID, commandName: "getState" }  → initial state
POST /perform { testID, commandName: "tap" }       → state after action
POST /perform { testID, commandName: "getState" }  → verify change persisted
```

---

## Known Issues & Workarounds

### Issue: PBXSourcesBuildPhase Duplication in xcodeproj

**Description**: When manually editing `TestableUIKitDemo.xcodeproj/project.pbxproj`, the `PBXSourcesBuildPhase` sections may become corrupted with duplicate `isa` declarations. This causes Xcode's build system to misinterpret target membership.

**Root Cause**: The pbxproj file is hand-generated (not via xcodegen/Tuist) and lacks safeguards against duplicate section definitions.

**Observed Symptom**: 
- Build succeeds but specific `.swift` files are unexpectedly compiled into wrong target
- Or: Build fails with "file not found" even though file exists on disk

**Remediation** (M-2 Session):
1. Identified duplicate `BC2E8FF2DF8EBC81139A4E0B` (DemoApp Sources) and `C4B254950335C0D58DF7380A` (TestableUIKit Sources)
2. Consolidated each into single, clean definition
3. Verified DemoApp Sources includes both `DemoApp.swift` + `LoginButton.swift`
4. Verified TestableUIKit Sources includes `AnyTestable.swift` + `JSONValue.swift` + `TestableServer.swift`
5. Ran `clean build` and verified Phase A/B tests pass

**Recommendation** (M-3 Scope):
- Migrate to xcodegen or Tuist for declarative project generation
- This eliminates hand-edit risk and provides version-control-friendly YAML/JSON config

**Early Detection**:
To detect duplicate `isa` blocks before they cause build failures, run:
```bash
grep -c "isa = PBXSourcesBuildPhase" TestableUIKitDemo.xcodeproj/project.pbxproj
```
**Expected value**: 2 (one per target: DemoApp + TestableUIKit)  
**Warning threshold**: ≥4 indicates duplication.

### Issue: DerivedData Cache Stale State

**Description**: After modifying `.swift` files in target membership or changing build settings, Xcode may cache stale compilation state in DerivedData.

**Remediation**: Always run `rm -rf DerivedData && xcodebuild ... clean build` after structural changes to pbxproj.

---

## Future Enhancements

- [ ] **M-3**: Multi-device matrix testing (iOS 17–26 simulator variants)
- [ ] **M-3**: xcodegen migration for pbxproj maintenance
- [ ] **M-4**: setProperty command for dynamic state manipulation
- [ ] **M-4**: CI/CD integration (GitHub Actions, GitLab CI examples)
- [ ] **Beyond**: Real device support (not just Simulator)
- [ ] **Beyond**: Async/await test composition helpers

---

## References

- `docs/ipc-protocol.md` — HTTP API specification
- `run_test.py` — Python test runner (Phase A/B examples)
- `DemoApp/LoginButton.swift` — Reference AnyTestable implementation

