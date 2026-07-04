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
protocol AnyTestable: AnyObject, Sendable {
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
actor TestableRegistry {
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
│   │   ├── AnyTestable.swift         # Protocol / Registry / TestError definitions
│   │   ├── JSONValue.swift           # Wire format enum
│   │   ├── TestableServer.swift      # HTTP server + PerformRequest
│   │   └── LoginButtonCore.swift     # Shared state struct + pure command-processing functions (shared by CLI and SwiftUI)
│   └── TestableUIKitDemo/
│       └── main.swift                # CLI executable entry point
├── DemoApp/
│   ├── DemoApp.swift                 # iOS App entry point
│   ├── LoginButton.swift             # SwiftUI AnyTestable implementation (@MainActor/@Published)
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

All commands return `[String: JSONValue]` after execution (5 fixed keys).
Command logic is consolidated in pure functions in `LoginButtonCore.swift`, shared by both CLI and SwiftUI.

### Unified Command Table (getState / tap / setProperty / setEnabled)

| Command | parameters | Side effects | CLI | iOS(SwiftUI) |
|---|---|---|---|---|
| `getState` | none | none | ✅ | ✅ |
| `tap` | none | guard isEnabled (no-op when disabled); isEnabled=false; title="Logged In" | ✅ | ✅ |
| `setProperty` | `{"key": string, "value": <value>}` | Update specified property | ✅ | ✅ |
| `setEnabled` | bool | Directly set isEnabled | ✅ | ✅ |

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
  var state = _state
  applyTap(to: &state)   // Pure function in LoginButtonCore (guard isEnabled; isEnabled=false; title="Logged In")
  _state = state
  return describedState
```

**tap Semantics (S2 finalized)**:
- `guard state.isEnabled else { return }` — no-op when disabled (mirrors real-user behavior)
- `state.isEnabled = false` — prevents double-submit
- `state.title = "Logged In"` — visible login result (proof of `@Published` re-render)

IPC `perform` always reaches the model (the precondition for introspection — the component can always be driven).  
The semantic gate (guard isEnabled) is held by `applyTap` on the model side, not by the view-layer `.disabled()`.

### setProperty (Setter)

```swift
case "setProperty":
  var state = _state
  try applySetProperty(to: &state, parameters: parameters)
  _state = state
  return describedState
```

### setEnabled (Quick Toggle)

```swift
case "setEnabled":
  var state = _state
  try applySetEnabled(to: &state, parameters: parameters)
  _state = state
  return describedState
```

**Key principle**: All commands return state in the same `[String: JSONValue]` format for consistency.

---

## Testing Philosophy

### Approach A vs Approach B — In-Process Introspection Testing vs XCUITest

#### Approach A (In-Process Introspection Testing — the backbone of TestableUIKit)

```
IPC /perform tap
  → TestableServer (background queue)
  → Task { @MainActor in await perform("tap") }
  → applyTap (pure function in LoginButtonCore)
  → @Published state change (isEnabled=false / title="Logged In")
  → SwiftUI re-render
```

- **Single convergence point: `perform`**. Both CLI and SwiftUI implementations converge at this single point.
- IPC **bypasses** the `.disabled()` view gate (it drives the model directly).
- The semantic gate (guard isEnabled) lives inside `applyTap` (on the model side).
- Background-initiated `@Published` changes correctly hop to SwiftUI re-renders via `Task { @MainActor in }`.

#### Approach B (XCUITest / UIKit sendActions)

- User input event → UIKit/SwiftUI view layer → `.disabled()` check → action handler
- Outside the scope of TestableUIKit. This is XCUITest's domain.
- The two approaches are complementary: Approach A directly tests a component's **internal state**; Approach B tests **user experience (including view-layer gates)**.

---

### Phase A: Network Path Verification

Ensures Simulator ↔ Host communication is working:
```bash
GET /ping → {"status": "ok"}
```

### Phase B: Logic Verification

Ensures UI state responds to commands:
```bash
POST /perform { testID, commandName: "getState" }  → initial state (isEnabled:true, title:"Log In")
POST /perform { testID, commandName: "tap" }       → state change (isEnabled:false, title:"Logged In")
POST /perform { testID, commandName: "getState" }  → confirm change (isEnabled:false, title:"Logged In" persists)
```

**Significance of Phase B**: Validates the full path from IPC tap → `@Published` change → SwiftUI re-render in a single test.  
The change in `title` ("Log In" → "Logged In") is the clearest evidence of re-rendering.

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

### Issue: TestableUIKit Framework Bundle Identifier (Resolved)

**Description**: The framework's `PRODUCT_BUNDLE_IDENTIFIER` was originally a placeholder (`com.testable.*`) assigned for build completion during M-3a xcodegen integration.

**Status**: ✅ Resolved (2026-06-25, STEP3 task 5) — finalized to the `dev.plateworks.*` namespace.

**Resolution**:
- Framework: `dev.plateworks.TestableUIKit`
- DemoApp: `dev.plateworks.TestableUIKitDemo`
- Updated in `project.yml` (2 places) and `.github/workflows/ci.yml` (simctl launch target).

**Current Impact**: 
- No impact on functionality (framework works correctly with any ID)
- Namespace now stable for distribution beyond localhost testing

---

## Future Enhancements

- [ ] **M-3**: Multi-device matrix testing (iOS 17–26 simulator variants)
- [ ] **M-3**: xcodegen migration for pbxproj maintenance
- [x] **M-5 Step 0**: Resolved component dual-implementation divergence (unified getState/tap/setProperty/setEnabled interface, 5-key describedState, LoginButtonCore DRY extraction)
- [x] **S2**: Approach A finalized with minimal proof (applyTap login-style transition, single `perform` convergence point, XCUITest boundary documented)
- [ ] **M-5**: Complete Phase B of run_test.py against CLI executable (Simulator verification)
- [ ] **M-4**: CI/CD integration (GitHub Actions, GitLab CI examples)
- [ ] **Beyond**: Real device support (not just Simulator)
- [ ] **Beyond**: Async/await test composition helpers

---

## M-4 Theme Candidates (partially completed in M-5 Step 0)

### A: setProperty Extension ✅ (completed in M-5 Step 0)

**Overview**: `setProperty` command now supports all 5 properties including isHidden / alpha / backgroundColor

**Implementation**: Handled in `applySetProperty` in `LoginButtonCore.swift`. Shared by CLI and SwiftUI.

**Effort**: Completed

---

### B: Test Runner Promotion

**Overview**: Promote `run_test.py` to a formal test suite

**Current state**: Python script (Phase A/B/B-5 integration tests)

**Target frameworks**:
- pytest (Python test integration)
- or XCTest (native Swift integration)

**CI integration**: Include in `xcodebuild test` or as a separate workflow job

**Effort**: 0.5–1 session

---

### C: SwiftUI Component Support

**Overview**: Migrate from CLI stub implementation to real SwiftUI components

**Current state (STEP 3 complete)**: `Counter` (testID: `scene.demo.counter`) is instrumented

**Goal**: Wrap real SwiftUI `Button`, `Toggle`, etc. as Testable

**Implementation patterns (① completed / ② next task)**:

#### ① Declarative registration via ViewModifier (STEP 3 complete)

Provides the `.testable(_:)` extension method in `Sources/TestableUIKit/TestableView.swift`.

```swift
// Component author's code (no manual register call needed)
CounterView(counter: counter)
  .testable(counter)
```

- `TestableRegistrationModifier` (conforming to `ViewModifier`) automatically calls
  `await TestableRegistry.shared.register(testable)` when the View first appears (`.task`)
- **Naming note**: `@testable` is reserved by Swift's `@testable import`, so attribute syntax cannot be used.
  Method syntax (`.testable(_:)`) is used instead to avoid the conflict.
- `@available(iOS 15.0, macOS 13.0, *)` — minimum availability aligned with the `.task` modifier requirement

#### ② Registry injection via Environment key (STEP 4 complete)

The global singleton (`TestableRegistry.shared`) has been removed. STEP 4 implements Registry injection into the View tree using a custom `EnvironmentKey`.

**Approach**: `EnvironmentKey` + `@Environment(\.testableRegistry)` (`TestableEnvironment.swift`)

**Why not EnvironmentObject**: `EnvironmentObject` requires `ObservableObject` (a `@MainActor` class), but `TestableRegistry` is an `actor` and cannot conform. The custom `EnvironmentKey` approach allows dependency injection while preserving the actor type.

**Injection architecture (DemoApp)**:
1. `RootView` creates one `TestableRegistry` instance as `@State private var registry = TestableRegistry()`
2. Injects it into the entire View tree via `.environment(\.testableRegistry, registry)`
3. Passes the same `registry` to `TestableServer(port:registry:)` inside `.task`
4. `CounterView.testable(counter)` → `TestableRegistrationModifier` reads `@Environment(\.testableRegistry)` and auto-registers

**CLI (`TestableUIKitDemo/main.swift`)**: No SwiftUI environment is available, so a local `registry` is created directly, passed to `TestableServer(port:registry:)`, and components are registered via `await registry.register(button)`.

**defaultValue risk**: If `.environment()` injection is missed, components register with `TestableRegistryKey.defaultValue` (an empty, isolated Registry), which is separate from the server's Registry (silent failure). Injecting correctly avoids this.

**Effort**: ① Complete (STEP 3) / ② Complete (STEP 4)

**Effort addendum (loginButton migration)**: The `loginButton` component in `DemoApp` (testID: `scene.demo.login.button`) was migrated to the `.testable(loginButton)` ViewModifier. The manual `await registry.register(loginButton)` inside `.task` was removed, unifying the registration approach with Counter. Implementation complete (STEP 4.5).

#### Instrumented Components (as of STEP 2)

| Component | testID | State type | Commands | Implemented in |
|---|---|---|---|---|
| Counter | `scene.demo.counter` | `Int` / `Bool` | getState, increment, decrement, reset, setProperty | STEP 3 |
| LoginButton | `scene.auth.loginButton` | `String` / `Bool` / `Double` | getState, tap, setProperty, setEnabled | STEP 4 |
| TextInput | `scene.demo.textInput` | `String` x3 / `Bool` | getState, clear, setProperty | STEP 2 |
| OnOffSwitch | `scene.demo.onOffSwitch` | `Bool` / `String` / `Bool` | getState, toggle, setProperty | STEP 2 |
| RangeSlider | `scene.demo.rangeSlider` | `Double` x3 | getState, reset, setProperty | STEP 2 |

**STEP 2 additional validation (2026-06-22)**: TextInput, OnOffSwitch, and RangeSlider were newly instrumented. Core layer (pure functions → 86 XCTest PASS) and SwiftUI Views (.testable() declarative registration) follow the established pattern. pytest E2E tests added (connectivity verified in test_swiftui_new_components.py).

---

### E: MCP Wrapper (STEP 1.5 implemented — 2026-06-22)

**Overview**: A standalone MCP server that thinly wraps TestableUIKit's HTTP IPC (localhost:8888) as MCP tools, allowing Claude to directly drive and inspect the describedState of a running iOS UI.

**Implementation location**: `mcp_server/` (bundled with TestableUIKit; not co-located with ProjectDeck)

#### Exposed MCP Tools (4 tools)

| MCP tool | Wraps | Returns | Purpose |
|---|---|---|---|
| `ui_ping` | `GET /ping` | `{status: "ok"}` | Server liveness check |
| `ui_getState(testID)` | `POST /perform` getState | describedState opaque dict | State retrieval → AI asserts expected values |
| `ui_perform(testID, command, params)` | `POST /perform` | describedState opaque dict | Execute tap/setProperty/setEnabled |
| `ui_screenshot` | `GET /screenshot` (primary) → simctl fallback | `{image_base64, format}` | Initial layout check (works on Simulator and physical device) |

#### Design Principles

- **Thin wrapper**: No business logic — HTTP relay only
- **describedState is an opaque dict**: No assumption of fixed keys (forward-compatible with STEP 2)
- **Stateless**: The MCP server itself holds no state
- **On-demand only**: Not always running (start with `python3 mcp_server/testableui_mcp.py`)

#### File structure

```
mcp_server/
  ipc_helpers.py        # Pure helpers (no external deps; L1 testable)
  testableui_mcp.py     # FastMCP server implementation
  requirements.txt      # mcp>=1.0.0, requests>=2.28.0
Tests/unit/
  conftest.py           # no-op override for autouse reset_state
  test_mcp_helpers.py   # L1 pytest 29 tests (no Simulator required)
```

#### How to Start

```bash
# Prerequisite: DemoApp is running in the Simulator (listening on localhost:8888)
cd projects/TestableUIKit
.venv/bin/pip install -r mcp_server/requirements.txt
python3 mcp_server/testableui_mcp.py
```

#### Test Loop Enabled

```
Build → Launch Simulator → [AI] operate via ui_perform → assert state with ui_getState
      → initial layout check via ui_screenshot → only anomaly candidates escalated to human (L5)
```

#### Out of Scope (Future Work)

- `GET /components` (retrieve testID list): requires addition on the TestableServer side → merge with STEP3
- Auxiliary MCP (`run_tests(scheme)`, etc.): replaceable with Bash; low priority

---

### E2: MCP Server — Swift Rewrite (SPM distributable — 2026-06-24)

**Overview**: The Python MCP server (`mcp_server/`) from §E has been rewritten in Swift (using the MCP swift-sdk) and is now distributable via SwiftPM. It starts with a single `swift run` command, no `.venv`/Python dependency needed. The four single-command tools, HTTP contract, and stateless design are identical to the Python version (parity maintained).

> **[Implementation note — 2026-07-04]** This section is authoritative (implementation lives in `mcp-swift/`, Swift). The Python version in `mcp_server/` is frozen as a historical record from §E and remains as a parallel reference until the retirement conditions below are met. Going forward, MCP server spec changes are updated in this section (and `docs/ipc-protocol.md`) as the source of truth.

**Implementation location**: `mcp-swift/` (**independent sub-package** — separate from the root `Package.swift`)

#### Why an independent sub-package? (dependency isolation design decision)

The MCP swift-sdk requires the following (verified empirically):

| Item | swift-sdk requirement | Main package | Conflict |
|---|---|---|---|
| swift-tools-version | 6.1 (all versions 6.0+) | 5.9 | Yes |
| platform | iOS 16 / macOS 13 | iOS 15 / macOS 13 | iOS conflict |
| transitive deps | swift-system / swift-log / swift-nio / eventsource etc. | None (zero deps) | Yes |

SwiftPM resolves **the entire dependency graph of a package**, not just the products you use. Adding swift-sdk to the root `Package.swift` would drag all consumers of the `TestableUIKit` library into iOS 16, Swift 6, swift-system, and more. This would violate the core constraint: **zero library external dependencies + maintain iOS 15 support**.

The MCP server communicates exclusively via **HTTP IPC** and does not import TestableUIKit's Swift types, so no source sharing is needed. This allows complete separation into an independent sub-package, leaving the root `Package.swift` entirely unchanged.

> **How to verify "zero library dependencies" (consumer perspective)**: Running `swift build` at the root resolves only the main package's dependency graph — swift-sdk does not appear (because `mcp-swift/` is a separate package and is not pulled in). swift-sdk is only fetched when running `swift build` inside `mcp-swift/`. The two package graphs must not intersect — that is the condition for isolation to hold.

#### Target structure

```
mcp-swift/
  Package.swift                              # tools 6.0 / macOS13 / swift-sdk dependency
  Sources/
    TestableUIKitMCPCore/   IPCHelpers.swift # Pure functions (no external deps; XCTest target)
                            Scenario.swift   # Declarative scenario model, parsing, assert evaluation (pure functions)
    TestableUIKitMCP/       main.swift       # executable (swift-sdk dependency is here only)
  Tests/
    TestableUIKitMCPCoreTests/IPCHelpersTests.swift  # L1 XCTest
                              ScenarioTests.swift     # L1 XCTest (scenarios)
```

- `TestableUIKitMCPCore`: host/port resolution, URL construction, perform payload building, simctl command generation, loopback detection, and **declarative scenario parsing/assert evaluation/aggregation**. Machine-verified without swift-sdk dependency (`IPCHelpers` maps 1:1 to Python `ipc_helpers.py`; `Scenario`/`ScenarioEvaluator` are new Swift-only features).
- `TestableUIKitMCP`: Manually registers tools with MCP `Server` and starts via `StdioTransport`. HTTP relay uses `URLSession`. `ui_screenshot` uses `GET /screenshot` as primary path, with simctl fallback for loopback only (same path as Python version). `ui_runScenario` is a thin orchestration layer that forwards each scenario step to `POST /perform` via `IPCHelpers.buildPerformPayload` and evaluates responses with `ScenarioEvaluator.evaluateExpect`.

#### Exposed MCP Tools (5 tools)

| MCP tool | Wraps | Returns | Purpose |
|---|---|---|---|
| `ui_ping` | `GET /ping` | `{status: "ok"}` | Server liveness check |
| `ui_getState(testID)` | `POST /perform` getState | describedState opaque dict | State retrieval → AI asserts expected values |
| `ui_perform(testID, command, params)` | `POST /perform` | describedState opaque dict | Execute tap/setProperty/setEnabled |
| `ui_screenshot` | `GET /screenshot` (primary) → simctl fallback | `{image_base64, format}` | Initial layout check (works on Simulator and physical device) |
| `ui_runScenario(scenario)` | `POST /perform` forwarded for multiple steps | `ScenarioResult` (per-step pass/fail, assert details, summary) | Execute a declarative multi-step UI scenario in a single call |

**When to use each**:
- **AI Dynamic Scenarios** (`ui_getState` → decide → `ui_perform` → `ui_screenshot`): Exploratory driving where the AI reads `describedState` at each step to decide the next action.
- **`ui_runScenario` Declarative Scenarios**: Define a known sequence of operations and expected values as a single JSON document. Execution is deterministic without per-step AI decisions — ideal for regression checks. See `Example/scenarios/*.json` for examples.

**⚠️ action enum sync note**: The authoritative enumeration of commands (actions) executable in declarative scenarios is the `ScenarioAction` enum and `ScenarioAction.known` array in `mcp-swift/Sources/TestableUIKitMCPCore/Scenario.swift`. When implementing a new command (tap / increment, etc.), always sync the following locations:
- Add a constant to `ScenarioAction` (e.g., `setEnabled = "setEnabled"`)
- Add to the `ScenarioAction.known` array
- Update the `enum` list in `Example/scenarios/scenario.schema.json` (so AI recognizes valid actions)
- Update the "Standard Commands" or "Component-Specific Commands" section in `docs/ipc-protocol.md` (spec doc)
- Update the "action catalog" in `docs/scenario-authoring.md` (user doc)

#### How to Run

```bash
# Prerequisite: DemoApp is running on a device/Simulator (listening on :8888)
cd projects/TestableUIKit/mcp-swift
swift run TestableUIKitMCP
# Override connection target: TESTABLE_IPC_HOST=192.168.0.181 swift run TestableUIKitMCP
```

#### Verification Status

- **Machine-verified**: Core pure function XCTest 41 green. MCP stdio handshake demonstrated (`initialize` → `tools/list` confirms 4 tools registered; `tools/call ui_ping` gracefully fails with `isError` when app is not running).
- **VQ/review lane**: The success path for live app responses (4-tool live drive parity against a running DemoApp) requires a real device/Simulator and is deferred to verify-queue.

#### Python version (`mcp_server/`) retirement conditions

Both versions will **run in parallel** until the following conditions are met, at which point the Python version will be retired:

1. Swift version 4-tool live drive parity is confirmed on a real device/Simulator (VQ closed).
2. `cd mcp-swift && swift test` is integrated into CI and passing green.
3. README / SETUP startup instructions are consolidated to the Swift version.

Until retirement, the Python version is authoritative (live-tested), while the Swift version is newer (desk-verified + protocol-tested).

---

### D: Physical Device Testing Support

**Overview**: Extend support from iOS Simulator to real iPhone testing

**Prerequisites**:
- Provisioning Profile setup
- Physical iPhone UUID management
- IPC over Wi-Fi network (extending from localhost:8888 to Wi-Fi)

**CI configuration**:
- GitHub Actions with physical device configuration (App Store Connect key, etc.)
- Or a local runner (machine with physical device connected)

**Effort**: 1–2 sessions (high cost)

---

### D Code Foundation (Implemented — 2026-06-22)

The pure code changes required for LAN-based IPC support have been implemented ahead of time. Physical hardware, Provisioning, and device pairing are out of scope (to be performed by a human in a later step).

**Server-side `TestableServer` bind extension**:
- Added `host` argument to `init(port:host:registry:)` (default `"127.0.0.1"` = loopback only)
- Specifying `"0.0.0.0"` binds to all interfaces (LAN-accessible)
- Runtime bind address is controlled via `NWParameters.requiredLocalEndpoint`
- Exposed as `public let host: String` property
- Backward compatible: existing `TestableServer(port: 8888, registry: registry)` calls work without the argument (no regression)

**Backward compatibility note**: The previous implementation only printed "localhost" but actually bound to all interfaces. This implementation correctly restricts runtime binding to loopback (`127.0.0.1`). Since all clients connect from localhost, there is no observable impact. This is an intentional narrowing for improved security.

**Client-side connection target overriding**:
- `ipc_helpers.py`: added `resolve_ipc_host_port(env:)` (pure function — L1 testable via env argument)
  - `TESTABLE_IPC_HOST` environment variable overrides the connection host (default: `localhost`)
  - `TESTABLE_IPC_PORT` environment variable overrides the connection port (default: `8888`)
  - Invalid port strings fall back to the default value
- `mcp_server/testableui_mcp.py`: resolves host/port from env at startup and generates `_IPC_BASE`
- `Tests/conftest.py` / `run_test.py`: dynamically generates BASE_URL via `resolve_ipc_host_port()`

**L1 tests added**:
- Swift: `Tests/TestableUIKitTests/TestableServerTests.swift` (10 tests: default values, LAN-public host, backward compatibility)
- Python: `TestResolveIpcHostPort` in `Tests/unit/test_mcp_helpers.py` (13 tests)
- DoD: `swift test` 96 PASS / pytest unit 42 PASS / commit `7d81160`

**Remaining (deferred to VQ)**: Verify real Wi-Fi communication from a physical iPhone after pairing → see `docs/verify-queue.md`

---

### D Extension: `ui_screenshot` Physical Device Support — Provider Injection Pattern (Implemented — 2026-06-23)

**Background**: During the MCP live PoC (3/4 tools driven on a physical device), `ui_screenshot` was the only tool that depended on `simctl io booted screenshot` (Simulator-only) and could not run on a real device.

**Approach (Route A)**: In-app capture → IPC response. A new `GET /screenshot` endpoint is added to `TestableServer`; the app renders its root view as PNG and returns it base64-encoded over HTTP. `ui_screenshot()` simply calls this endpoint as the primary path.

**screenshotProvider injection design**:
- Added optional `screenshotProvider: (@MainActor () async -> Data?)?` to `TestableServer(port:host:registry:screenshotProvider:)` (default nil; backward compatible)
- `GET /screenshot` calls the provider, base64-encodes the result, and returns `{"image_base64":..., "format":"png"}`. Returns `{"error":"screenshotProvider not configured"}` (503) when not injected
- The library has no knowledge of the closure internals (UIKit-free; stateless preserved)
- `DemoApp.swift` creates and injects the key-window capture closure (`UIGraphicsImageRenderer` + root view from `UIApplication.shared.connectedScenes`), keeping UIKit dependencies on the app side

**Python-side `ui_screenshot()` fallback strategy**:
- Primary path: `GET /screenshot` (works on both Simulator and real device)
- Fallback: only when the host is loopback (`127.0.0.1` / `localhost`) and the `/screenshot` endpoint returns 4xx/5xx or fails to connect, fall back to `simctl io booted screenshot` (backward compatibility for Simulator)
- Fallback detection is a pure function (`is_loopback_host(host)` in `mcp_server/ipc_helpers.py`), testable at L1

**L1 tests added**:
- Swift: Hitting `GET /screenshot` on a `TestableServer` with a stub provider injected returns JSON containing base64 (4 tests)
- Python: `build_screenshot_url`, fallback detection, passthrough (17 tests added)
- DoD: `swift test` 100 PASS / pytest 59 PASS / commit `78716fd`

**Remaining (deferred to VQ)**: After reinstalling DemoApp on a real device (iPhone `192.168.0.181`), verify that calling `ui_screenshot` with `TESTABLE_IPC_HOST=192.168.0.181` returns a real PNG base64 → see `docs/verify-queue.md`

---

## References

- `docs/ipc-protocol.md` — HTTP API specification
- `run_test.py` — Python test runner (Phase A/B examples)
- `DemoApp/LoginButton.swift` — Reference AnyTestable implementation

