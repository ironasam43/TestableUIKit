# TestableUIKit Productization Roadmap

**Last updated**: 2026-06-23  
**Scope**: TestableUIKit project as a whole

---

## 1. Definition of Productization

**Productization** = the state where others can integrate it into their app's UI components and write UI tests

At the current stage (Phase 0 PoC), we have reached the point of "testing your own demo yourself." Productization requires the following:

- Formal test runner suite (confirm Response schema for tap/setProperty)
- Real SwiftUI component support
- Distribution / onboarding DX (semver tags, README, instrumentation guide, samples)
- Robustness improvements (port conflicts, multiple instances, error responses)

---

## 2. Current Status (Completed)

> **Progress note (2026-06-23)**: Compared to the planned route (STEP1→2→3→4), in practice **STEP 2 exceeded its goals and STEP 4 was completed in full**, and **STEP 3 (Distribution & DX) is also complete** (2026-06-25). See each STEP heading for details.

**Core implementation**:
- `AnyTestable` protocol (testID / describedState / perform) ✅
- `TestableServer` (HTTP over localhost:8888 / `0.0.0.0` binding for physical devices + `GET /screenshot` support) ✅
- `TestableRegistry` ✅ — **singleton removed; migrated to SwiftUI Environment key injection** (STEP 4 related refactor)
- Unified command interface (`getState` / `tap` / `setProperty` / `setEnabled`) ✅
- 5-key fixed describedState (isEnabled / title / isHidden / alpha / backgroundColor) ✅

**Example implementations / instrumentation**:
- iOS DemoApp (UIKit LoginButton) ✅
- CLI executable (TestableUIKitDemo) ✅
- DRY extraction of Core logic (LoginButtonCore) ✅
- **`.testable(_:)` ViewModifier implemented** (`Sources/TestableUIKit/TestableView.swift`) ✅
- **Diverse component instrumentation**: 4 Core implementations — `CounterCore` / `TextInputCore` / `OnOffSwitchCore` / `RangeSliderCore` ✅

**MCP integration**:
- **Standalone MCP server (`mcp_server/testableui_mcp.py`) implemented**: 4 tools — `ui_ping` / `ui_getState` / `ui_perform` / `ui_screenshot` ✅

**Quality**:
- CI all 3 jobs ✅ PASS:
  - Swift Package Unit Tests
  - Build iOS DemoApp
  - Phase 0 PoC - Simulator Boot, App Launch & Loopback
- **Test scale: `swift test` 100 PASS / `pytest` 59 PASS** ✅ (significant progress from 23 PASS at PoC start)

**Documentation**:
- `docs/design.md` (architecture / Definition A/B / test philosophy / §D physical device support) ✅
- `docs/ipc-protocol.md` (HTTP API spec / `GET /screenshot` added) ✅

---

## 3. Four Steps to Productization

### STEP 1: Promote the Test Runner

**Description**: Integrate `run_test.py` into a formal pytest test suite and finalize the Response schema for tap and setProperty

**Current state**: 
- run_test.py contains integration tests (Phase A/B/B-5)
- Only getState has assertions
- Response schema for tap/setProperty is not yet finalized (spec being confirmed by full-line review of run_test.py)

**Completion conditions**:
1. Finalize the tap/setProperty Response schema in `docs/ipc-protocol.md`
2. Re-implement run_test.py as a pytest framework (fixtures / parametrize, etc.)
3. Run the `pytest` job as part of the CI workflow
4. 23+ tests PASS (in parallel with existing swift test)

**Effort**: Small (0.5–1 session)

**Design reference**: [Design B](design.md#b-test-runner-promotion) — Test runner integration

---

### STEP 2: SwiftUI Component Support ✅ Complete (exceeded goals)

**Description**: Migrate from CLI stub implementation (CLIDemoLoginButton) to real SwiftUI components (Button / Toggle / TextField, etc.). Make any View Testable via ViewModifier + Registry

**Actual results (2026-06-23)**: 
- ✅ `.testable(_:)` ViewModifier implemented (`Sources/TestableUIKit/TestableView.swift`). Transparently wraps any SwiftUI View as Testable
- ✅ TestableRegistry access via Environment key injection (migrated from EnvironmentObject in STEP 4 — exceeded original goal)
- ✅ Diverse component instrumentation: 4 Core implementations — `CounterCore` / `TextInputCore` / `OnOffSwitchCore` / `RangeSliderCore` (exceeds original target of "3 or more")
- ✅ Instrumentation tests demonstrated for Counter / TextInput / OnOffSwitch / RangeSlider (part of `swift test` 100 PASS)

**Completion conditions** (all achieved):
1. ✅ Implement `.testable(_:)` ViewModifier. Transparently wraps any SwiftUI View as Testable
2. ✅ Registry access via Environment key injection (singleton-free design surpassing the EnvironmentObject approach)
3. ✅ DemoApp component count increased to 3 or more (4 Cores)
4. ✅ Instrumentation tests demonstrated for various Views (Counter / TextInput / OnOffSwitch / RangeSlider)

**Design reference**: [Design C](design.md#c-swiftui-component-support) — SwiftUI component support

---

### STEP 3: Distribution & DX ✅ Complete (2026-06-25 / Bundle ID pending HUMAN decision)

**Description**: Foundation for open-sourcing and adoption support. SPM semver tagging, README getting-started, custom component instrumentation guide, minimal sample, hardening (port conflicts, multiple instances, error responses)

**Actual results (2026-06-25 / inbox `2026-06-25-step3-distribution-dx.md` consumed)**: 
- Full distribution packaging for external users in place. Core functionality and physical device support completed in STEP 4 / CI green
- Port 8888 conflict behavior defined via `TestableServer.State` + `onStateChange`; graceful shutdown implemented via `stop()`

**Completion conditions**:
1. ✅ `docs/getting-started.md`: Step-by-step guide for instrumenting your component in 5 minutes (known pitfalls ①–③ documented)
2. ✅ `docs/troubleshooting.md`: Extracted and expanded from SETUP.md / README (port conflicts, multiple instances, timeouts, missing Registry sharing)
3. ✅ semver tag v0.1.0 published via GitHub Releases (https://github.com/ironasam43/TestableUIKit/releases/tag/v0.1.0)
4. ✅ README updated with link to getting-started (top banner + documentation table)
5. ✅ Bundle ID finalized — confirmed as `dev.plateworks.*` namespace (project.yml 2 locations + ci.yml simctl launch)
6. ✅ TestableServer gains graceful shutdown (`stop()`), state notifications (`onStateChange`), and port conflict detection (`.failed`). XCTest +4 (104 PASS)
7. ✅ `Example/`: Minimal sample for custom component instrumentation (`MyToggleExample.swift` + README)

**Design reference**: [Design Distribution & DX](design.md) — Documentation infrastructure built in STEP 3

---

### STEP 4: Physical Device Support ✅ Complete (completed ahead of schedule)

**Description**: Extend from iOS Simulator to running tests on a real iPhone device. Provisioning Profile and Device UUID management, Wi-Fi IPC (localhost:8888 → Wi-Fi endpoint)

**Actual results (2026-06-23)**: 
- ✅ Wi-Fi IPC established with physical iPhone at `192.168.0.181`. `DemoApp` publishes on `host: "0.0.0.0"` behind `#if DEBUG`
- ✅ All 4 MCP tools (`ui_ping` / `ui_getState` / `ui_perform` / `ui_screenshot`) **closed 4/4 physical device e2e**
- ✅ `ui_screenshot` via route A (`GET /screenshot` in-app capture) confirmed to retrieve device PNG without Simulator dependency (79,768 bytes / 960×1440 / PNG signature match)
- ✅ Connection switching via `TESTABLE_IPC_HOST` and physical device pairing procedure documented in SETUP.md / README

**Completion conditions** (status):
1. ✅ Provisioning Profile / physical device pairing procedure documented in SETUP.md
2. ✅ `TestableServer` listens on `0.0.0.0` (reachable at device IP:port)
3. 🟡 Connection target is manually specified via `TESTABLE_IPC_HOST` (procedure for DHCP changes documented; UUID auto-detection not implemented, covered operationally)
4. ⬜ Physical device integration into GitHub Actions not done (validated via local physical device e2e; CI automation is out of scope)
5. ✅ Confirmed test execution on real iPhone locally (4/4 tools driven)

**Note (reversal from recommended route)**: Originally "STEP 4 can be deferred," but in practice **STEP 4 was completed ahead of schedule**, leaving STEP 3 (Distribution & DX) partially remaining — a reversal of order. Early physical device e2e validation moved value demonstration forward, while STEP 3, needed for external release, became the bottleneck.

**Design reference**: [Design D](design.md#d-physical-device-testing-support) — Physical device test support

---

## 4. Recommended Route (original plan) vs Actual Progress

> **Actual progress (2026-06-23)**: STEP 1 ✅ → STEP 2 ✅ (exceeded goals) → **STEP 4 ✅ (completed ahead of schedule)** → STEP 3 ✅ (completed 2026-06-25). The following describes the original plan. In practice, physical device support (STEP 4) was completed early for value validation, leaving Distribution & DX (STEP 3) as the bottleneck for external release.

```
STEP 1 (Promote Test Runner) ✅
    ↓ [foundation complete]
STEP 2 (SwiftUI Components) ✅ exceeded goals
    ↓ [main goal complete = others can integrate]
    └─ parallel (partial) → hardening / lightweight STEP 3
    ↓
STEP 3 (Distribution & DX) ✅ complete (2026-06-25)
    ↓ [release-ready = usable by anyone]
STEP 4 (Physical Device Support) ✅ completed ahead of schedule (originally "can be deferred")
```

**Rationale (minimize rework)**:

1. **STEP 1 highest priority (foundation)**: Without finalizing the tap/setProperty schema, there is a risk of spec drift when instrumenting STEP 2 components. Finalize first to secure a stable IPC interface
2. **STEP 2 (main goal)**: Migrate from CLIDemoLoginButton PoC to real SwiftUI. This achieves "can integrate into your own component"
3. **STEP 3 (distribution)**: After STEP 2 completes the main goal, add surrounding infrastructure — docs, examples, bundle ID, etc. DX polish on top of a working product
4. **STEP 4 (physical device)**: Extension after confirming all features work in the Simulator. Not needed if Simulator is sufficient. Recommended to defer

With this ordering:
- STEP 1–2 achieve "productization" (others can integrate)
- STEP 3 makes it "usable by anyone"
- STEP 4 is "more convenient" (optional)

In reverse order (STEP 4 first, etc.), you invest heavily in physical device setup before use cases are clear — inefficient.

---

## References

- `docs/design.md` — Detailed specs for M-4 theme candidates A/B/C/D
- `docs/history.md` — Progress summary for milestones M-1 through M-5
- `docs/ipc-protocol.md` — HTTP API spec (to be extended in STEP 1)
- `handoff.md` — Project work notes
- `docs/oss-publication-roadmap.md` — GitHub OSS publication roadmap (LICENSE, untracking internal files, English translation, OSS standard preparation)
