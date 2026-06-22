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
│   │   ├── AnyTestable.swift         # Protocol / Registry / TestError 定義
│   │   ├── JSONValue.swift           # Wire format enum
│   │   ├── TestableServer.swift      # HTTP server + PerformRequest
│   │   └── LoginButtonCore.swift     # 共有状態 struct + 純粋コマンド処理関数（CLI・SwiftUI 共用）
│   └── TestableUIKitDemo/
│       └── main.swift                # CLI executable エントリポイント
├── DemoApp/
│   ├── DemoApp.swift                 # iOS App エントリポイント
│   ├── LoginButton.swift             # SwiftUI 版 AnyTestable（@MainActor/@Published）
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

全コマンドは実行後の `[String: JSONValue]` を返す（5キー固定）。
コマンドロジックは `LoginButtonCore.swift` の純粋関数に集約され、CLI・SwiftUI 双方で共有される。

### 統一コマンド表（getState / tap / setProperty / setEnabled）

| コマンド | parameters | 副作用 | CLI | iOS(SwiftUI) |
|---|---|---|---|---|
| `getState` | なし | なし | ✅ | ✅ |
| `tap` | なし | guard isEnabled（無効なら no-op）; isEnabled=false; title="Logged In" | ✅ | ✅ |
| `setProperty` | `{"key": string, "value": <value>}` | 指定プロパティを更新 | ✅ | ✅ |
| `setEnabled` | bool | isEnabled を直接設定 | ✅ | ✅ |

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
  applyTap(to: &state)   // LoginButtonCore の純粋関数（guard isEnabled; isEnabled=false; title="Logged In"）
  _state = state
  return describedState
```

**tap 意味論（S2 確定版）**:
- `guard state.isEnabled else { return }` — 無効なら no-op（実ユーザー同様に弾く）
- `state.isEnabled = false` — 二重送信防止
- `state.title = "Logged In"` — 可視なログイン結果（`@Published` 再描画の証拠）

IPC `perform` は常にモデルへ到達（内省の前提＝常にコンポーネントを駆動できる）。  
意味論ゲートはビュー層の `.disabled()` ではなくモデル側 `applyTap` が保持する。

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

### 定義A vs 定義B — in-process 内省テスト vs XCUITest

#### 定義A（in-process 内省テスト / TestableUIKit の背骨）

```
IPC /perform tap
  → TestableServer（background queue）
  → Task { @MainActor in await perform("tap") }
  → applyTap（LoginButtonCore 純粋関数）
  → @Published 状態変化（isEnabled=false / title="Logged In"）
  → SwiftUI 再描画
```

- **合流点は `perform` 一本**。CLI・SwiftUI の両実装がこの1点で合流する。
- IPC は `.disabled()` ビューゲートを**通らない**（モデル直叩き）。
- 意味論ゲート（guard isEnabled）は `applyTap` 内部（モデル側）に持たせる。
- バックグラウンド由来の `@Published` 変更は `Task { @MainActor in }` ホップで SwiftUI 再描画に正しく載る。

#### 定義B（XCUITest / UIKit sendActions）

- ユーザー入力イベント → UIKit/SwiftUI ビュー層 → `.disabled()` チェック → アクションハンドラ
- TestableUIKit の領域外。XCUITest が担う。
- 両者の棲み分け：定義A はコンポーネントの**内部状態**を直接検証、定義B は**ユーザー体験（ビュー層ゲート含む）**を検証。

---

### Phase A: Network Path Verification

Ensures Simulator ↔ Host communication is working:
```bash
GET /ping → {"status": "ok"}
```

### Phase B: Logic Verification

Ensures UI state responds to commands:
```bash
POST /perform { testID, commandName: "getState" }  → 初期状態（isEnabled:true, title:"Log In"）
POST /perform { testID, commandName: "tap" }       → 状態変化（isEnabled:false, title:"Logged In"）
POST /perform { testID, commandName: "getState" }  → 変化の確認（isEnabled:false, title:"Logged In" が持続）
```

**Phase B 実証の意義**: IPC tap → `@Published` 変化 → SwiftUI 再描画の全経路を 1 本で通す。  
`title` の変化（"Log In" → "Logged In"）が再描画の最も明瞭な証拠となる。

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
- [x] **M-5 Step 0**: コンポーネント2系統分裂解消（getState/tap/setProperty/setEnabled 統一 I/F・5キー describedState・LoginButtonCore DRY 抽出）
- [x] **S2**: 定義A確定・最小実証（applyTap ログイン風遷移・合流点 perform 一本・XCUITest 棲み分け docs 記録）
- [ ] **M-5**: run_test.py Phase B を CLI executable で完走（Simulator 検証）
- [ ] **M-4**: CI/CD integration (GitHub Actions, GitLab CI examples)
- [ ] **Beyond**: Real device support (not just Simulator)
- [ ] **Beyond**: Async/await test composition helpers

---

## M-4 テーマ候補（M-5 Step 0 で一部完了）

### A: setProperty 拡張 ✅（M-5 Step 0 で実装済み）

**概要**: `setProperty` コマンドで isHidden / alpha / backgroundColor を含む5プロパティをサポート

**実装**: `LoginButtonCore.swift` の `applySetProperty` で対応済み。CLI・SwiftUI 共通。

**工数**: 実施済み

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

**現状（STEP 3 完了）**: `Counter`（testID: `scene.demo.counter`）が計装済み

**目標**: 実 SwiftUI `Button` `Toggle` などを Testable にラップ

**実装パターン（① 実装済み / ② 次タスク）**:

#### ① ViewModifier による宣言的登録（STEP 3 実装済み）

`Sources/TestableUIKit/TestableView.swift` で `.testable(_:)` 拡張メソッドを提供。

```swift
// コンポーネント作者が書くコード（手動 register 不要）
CounterView(counter: counter)
  .testable(counter)
```

- `TestableRegistrationModifier`（`ViewModifier` 準拠）が View 表示開始時（`.task`）に
  `await TestableRegistry.shared.register(testable)` を自動実行
- **命名の注記**: `@testable` は Swift の `@testable import` で予約済みのため属性構文は使用不可。
  メソッド構文（`.testable(_:)`）を採用して衝突を回避
- `@available(iOS 15.0, macOS 13.0, *)` — `.task` 修飾子の最小要件に合わせた availability

#### ② Environment キーによる Registry 注入（STEP 4 実装済み）

グローバルシングルトン（`TestableRegistry.shared`）を廃止し、`EnvironmentKey` カスタムキー方式で
Registry を View ツリーへ注入する方式を STEP 4 で実装。

**採用方式**: `EnvironmentKey` ＋ `@Environment(\.testableRegistry)`（`TestableEnvironment.swift`）

**EnvironmentObject を採用しなかった理由**: `EnvironmentObject` は `ObservableObject`（`@MainActor` class）を
要求するが、`TestableRegistry` は `actor` のため準拠不可。actor を維持したまま依存注入できる
`EnvironmentKey` カスタムキー方式を選択した。

**注入アーキテクチャ（DemoApp）**:
1. `RootView` が `@State private var registry = TestableRegistry()` で Registry を1つ生成
2. `.environment(\.testableRegistry, registry)` で View ツリー全体へ注入
3. `.task` 内で同じ `registry` を `TestableServer(port:registry:)` へ渡す
4. `CounterView.testable(counter)` → `TestableRegistrationModifier` が `@Environment(\.testableRegistry)` で registry を受け取り自動 register

**CLI（`TestableUIKitDemo/main.swift`）**: SwiftUI 環境を持たないため、ローカル `registry` を直接生成して
`TestableServer(port:registry:)` へ注入し、コンポーネントを `await registry.register(button)` で直接登録。

**defaultValue リスク**: `.environment()` 注入を忘れた View では、登録先が
`TestableRegistryKey.defaultValue`（空の独立 Registry）となり、サーバの Registry と別物になる
（サイレント失敗）。正しく注入すれば問題なし。

**工数**: ① 完了（STEP 3）/ ② 完了（STEP 4）

**工数補追（loginButton 移行）**: `DemoApp` の `loginButton` コンポーネント（testID: `scene.demo.login.button`）も
`.testable(loginButton)` ViewModifier へ移行。RootView の `.task` 内の手動 `await registry.register(loginButton)` を廃止し、
Counter と登録方式を統一。実装完了（STEP 4.5）。

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

