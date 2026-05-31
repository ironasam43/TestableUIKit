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

### Issue: TestableUIKit Framework Bundle Identifier Is Placeholder

**Description**: The framework's `PRODUCT_BUNDLE_IDENTIFIER` is currently set to `com.testable.TestableUIKit` (project.yml L14), which is a placeholder assigned for build completion during M-3a xcodegen integration.

**Status**: ⚠️ Placeholder value (not final specification)

**Planned Resolution** (M-4 or distribution phase):
- Establish framework bundle ID policy (e.g., `com.example.testable-ui-kit` for open-source, company-specific for internal)
- Align with SPM/CocoaPods distribution requirements
- Document bundle ID contract in docs/packaging.md

**Current Impact**: 
- No impact on functionality (framework works correctly with any ID)
- Only relevant if distributing framework to multiple teams/devices beyond localhost testing

---

## Future Enhancements

- [ ] **M-3**: Multi-device matrix testing (iOS 17–26 simulator variants)
- [ ] **M-3**: xcodegen migration for pbxproj maintenance
- [ ] **M-4**: setProperty command for dynamic state manipulation
- [ ] **M-4**: CI/CD integration (GitHub Actions, GitLab CI examples)
- [ ] **Beyond**: Real device support (not just Simulator)
- [ ] **Beyond**: Async/await test composition helpers

---

## M-4 テーマ候補（未着手）

### A: setProperty 拡張

**概要**: 既存 `setProperty` コマンドで新しいプロパティをサポート

**対象プロパティ**:
- `isHidden` (bool) — UI の表示/非表示制御
- `alpha` (float 0.0-1.0) — 透明度
- `backgroundColor` (string) — 背景色（Hex / Named color）

**実装方法**: `CLIDemoLoginButton.perform()` の switch case 拡張（新 key 追加）

**工数**: 0.5〜1 セッション

---

### B: テストランナー統合

**概要**: `run_test.py` を正式な test suite に昇格

**現状**: Python スクリプト（Phase A/B/B-5 の integration テスト）

**対象フレームワーク**:
- pytest（Python テスト統合）
- または XCTest（Swift ネイティブ連携）

**CI 組み込み**: `xcodebuild test` に含める、または separate workflow ジョブ

**工数**: 0.5〜1 セッション

---

### C: SwiftUI コンポーネント対応

**概要**: CLI スタブ実装から実 SwiftUI コンポーネントへの移行

**現状**: `CLIDemoLoginButton` は `@MainActor class` の CLI デモ

**目標**: 実 SwiftUI `Button` `Toggle` などを Testable にラップ

**実装パターン**:
- ViewModifier で AnyTestable プロトコル適用
- EnvironmentObject で TestableRegistry アクセス

**工数**: 1〜2 セッション（設計変更大）

---

### D: 実機テスト対応

**概要**: iOS Simulator から実 iPhone での対応拡張

**前提条件**:
- Provisioning Profile セットアップ
- 実 iPhone の UUID 管理
- WiFi ネットワーク経由の IPC（localhost:8888 から Wi-Fi に拡張）

**CI 構成**:
- GitHub Actions に実機接続設定（App Store Connect キー等）
- または local runner（実機接続マシン）

**工数**: 1〜2 セッション（高コスト）

---

## References

- `docs/ipc-protocol.md` — HTTP API specification
- `run_test.py` — Python test runner (Phase A/B examples)
- `DemoApp/LoginButton.swift` — Reference AnyTestable implementation

