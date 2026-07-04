# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- OSS standard files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`,
  `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md`, `mcp-swift/README.md`
- Declarative scenario authoring support: `ScenarioAction.known` constants (9 commands),
  expanded MCP `inputSchema` with action enum and expect keys, JSON Schema for scenarios,
  and `docs/scenario-authoring.md` guide
- `ui_runScenario` MCP tool: executes multi-step JSON scenarios with per-step `expect` assertions

### Changed
- Full English localization of all source code comments, documentation, and public APIs
  (previously Japanese); `README.ja.md` added as Japanese translation companion

### Infrastructure
- Default branch renamed from `master` to `main`
- MIT LICENSE added
- Internal operational files (CLAUDE.md, handoff.md, docs/history.md, etc.)
  removed from git tracking via `.gitignore`

---

## [v0.2.0] - 2026-06-26

### Added
- **State-declarative high-level API** — two-tier abstraction over `AnyTestable`:
  - `TestableComponent<State>` (Tier 1): generic component with associated state type;
    eliminates hand-written `switch` boilerplate in `perform` implementations
  - Drop-in Tier 2 controls: `TestableStepper`, `TestableToggle`, `TestableTextField`,
    `TestableSlider`, `TestableButton` — zero-boilerplate computed-state registration
  - Full backward compatibility with existing `AnyTestable` hand-written approach
- **macOS Demo** (`Sources/TestableUIKitMacDemo/`): AppKit-based demo verifying all
  4 IPC tools (`ui_ping`, `ui_getState`, `ui_perform`, `ui_screenshot`) on macOS
- `e2e_macdemo.sh`: end-to-end shell script for macOS demo verification

### Changed
- `TestableServer` extended to support `AppKit`-based screenshot capture on macOS

---

## [v0.1.0] - 2026-06-10

### Added
- **Core library** (`TestableUIKit`):
  - `AnyTestable` protocol (`@MainActor`): `testID`, `describedState`, `perform`
  - `TestableServer`: HTTP server on `localhost:8888` with `GET /ping` and `POST /perform`
  - `JSONValue`: Codable JSON value type
  - `.testable(_:)` SwiftUI ViewModifier for declarative component registration
  - `TestableRegistry` with `@Environment` key injection (singleton removed)
  - `setProperty` command: `isHidden`, `alpha`, `backgroundColor` properties
- **Swift MCP server** (`mcp-swift/`): standalone Swift package wrapping the HTTP IPC as
  MCP tools for Claude / AI agent integration
  - Tools: `ui_ping`, `ui_getState`, `ui_perform`, `ui_screenshot`
  - Connection target configurable via `TESTABLE_IPC_HOST` / `TESTABLE_IPC_PORT` env vars
  - Physical device support (LAN Wi-Fi) via `GET /screenshot` provider injection
- **DemoApp** (`TestableUIKitDemo`): SwiftUI reference implementation with `Counter`,
  `TextInput`, `OnOffSwitch`, `RangeSlider` components instrumented via `.testable()`
- **IPC integration tests**: Python test runner (`run_test.py`) with pytest, Phase A/B test suites
- **CI** (`.github/workflows/ci.yml`): Swift Package unit tests, iOS DemoApp build, Phase 0 PoC job
- **Getting started guide** (`docs/getting-started.md`), **SETUP.md**, **IPC protocol spec**
  (`docs/ipc-protocol.md`), **architecture document** (`docs/design.md`)

### Infrastructure
- XcodeGen (`project.yml`) for Xcode project generation
- `Example/` directory with sample scenarios (`counter-flow.json`, `login-flow.json`)

---

[Unreleased]: https://github.com/ironasam43/TestableUIKit/compare/v0.2.0...HEAD
[v0.2.0]: https://github.com/ironasam43/TestableUIKit/compare/v0.1.0...v0.2.0
[v0.1.0]: https://github.com/ironasam43/TestableUIKit/releases/tag/v0.1.0
