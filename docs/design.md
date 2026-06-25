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

#### 計装済みコンポーネント一覧（STEP 2 時点）

| コンポーネント | testID | 状態型 | コマンド | 実装タイミング |
|---|---|---|---|---|
| Counter | `scene.demo.counter` | `Int` / `Bool` | getState, increment, decrement, reset, setProperty | STEP 3 |
| LoginButton | `scene.auth.loginButton` | `String` / `Bool` / `Double` | getState, tap, setProperty, setEnabled | STEP 4 |
| TextInput | `scene.demo.textInput` | `String` x3 / `Bool` | getState, clear, setProperty | STEP 2 |
| OnOffSwitch | `scene.demo.onOffSwitch` | `Bool` / `String` / `Bool` | getState, toggle, setProperty | STEP 2 |
| RangeSlider | `scene.demo.rangeSlider` | `Double` x3 | getState, reset, setProperty | STEP 2 |

**STEP 2 追加実証（2026-06-22）**: TextInput / OnOffSwitch / RangeSlider を新規計装。
Core 層（純粋関数 → XCTest で 86 PASS）と SwiftUI View（.testable() 宣言的登録）で既存パターンに統一。
pytest E2E 追加（test_swiftui_new_components.py にて疎通確認）。

---

### E: MCP ラッパー（STEP 1.5 実装済み・2026-06-22）

**概要**: TestableUIKit の HTTP IPC（localhost:8888）を MCP tool で薄くラップし、Claude が実行中の iOS UI を直接駆動・describedState を構造化検査できるようにする独立 MCP サーバ。

**実装場所**: `mcp_server/`（TestableUIKit 同梱・ProjectDeck 非同居）

#### 公開する MCP tool（4本）

| MCP tool | ラップ先 | 返り値 | 用途 |
|---|---|---|---|
| `ui_ping` | `GET /ping` | `{status: "ok"}` | サーバー死活確認 |
| `ui_getState(testID)` | `POST /perform` getState | describedState 不透明 dict | 状態取得 → AI が期待値照合 |
| `ui_perform(testID, command, params)` | `POST /perform` | describedState 不透明 dict | tap/setProperty/setEnabled 実行 |
| `ui_screenshot` | `GET /screenshot`（一次）→ simctl フォールバック | `{image_base64, format}` | 崩れ一次判定（Simulator/実機両対応） |

#### 設計原則

- **薄いラッパー**: ビジネスロジック不持ち・HTTP 中継のみ
- **describedState は不透明 dict**: キー固定を前提にしない（STEP2 前方互換）
- **状態レス**: MCP サーバー自体は状態を持たない
- **UIテスト時のみ起動**: 常駐しない構成（`python3 mcp_server/testableui_mcp.py` で起動）

#### ファイル構成

```
mcp_server/
  ipc_helpers.py        # 純粋ヘルパー（外部依存なし・L1 テスト可）
  testableui_mcp.py     # FastMCP サーバー実装
  requirements.txt      # mcp>=1.0.0, requests>=2.28.0
Tests/unit/
  conftest.py           # autouse reset_state の no-op override
  test_mcp_helpers.py   # L1 pytest 29テスト（Simulator 不要）
```

#### 起動方法

```bash
# 前提: DemoApp が Simulator 上で起動済み（localhost:8888 リッスン中）
cd projects/TestableUIKit
.venv/bin/pip install -r mcp_server/requirements.txt
python3 mcp_server/testableui_mcp.py
```

#### 実現するテストループ

```
ビルド → Simulator 起動 → [AI] ui_perform で操作 → ui_getState で状態 assert
       → ui_screenshot で崩れ一次判定 → 異常候補だけ人間（L5）へ
```

#### スコープ外（将来課題）

- `GET /components`（testID 一覧取得）: TestableServer 側に追加が必要→ STEP3 と合流
- 補助 MCP（`run_tests(scheme)` 等）: Bash で代替可・優先度低

---

### E2: MCP サーバ Swift 化（SPM 公開・2026-06-24）

**概要**: §E の Python 製 MCP サーバ（`mcp_server/`）を Swift（MCP swift-sdk）へ書き直し、SwiftPM で配布可能にした。`.venv`/Python 依存なしで `swift run` 一発で起動できる。公開 4 ツール・HTTP 契約・状態レス設計は Python 版と完全に同一（パリティ維持）。

**実装場所**: `mcp-swift/`（**独立 sub-package**。メイン `Package.swift` とは別パッケージ）

#### なぜ独立 sub-package なのか（依存封じ込めの設計判断）

MCP swift-sdk（`github.com/modelcontextprotocol/swift-sdk`）は実測で次を要求する:

| 項目 | swift-sdk の要求 | メイン package | 衝突 |
|---|---|---|---|
| swift-tools-version | 6.1（全バージョン 6.0+） | 5.9 | あり |
| platform | iOS 16 / macOS 13 | iOS 15 / macOS 13 | iOS で衝突 |
| transitive deps | swift-system / swift-log / swift-nio / eventsource ほか | なし（依存ゼロ） | あり |

SwiftPM は「使う product だけ」でなく**パッケージの依存グラフ全体を解決**するため、swift-sdk をメイン `Package.swift` に足すと library `TestableUIKit` の consumer まで iOS16・Swift6・swift-system 等へ巻き込む。これは差別化条件「**library 外部依存ゼロ・iOS15 維持**」を破壊する。

MCP サーバは TestableUIKit の Swift 型を import せず **HTTP IPC のみ**で通信するため、ソース共有が不要。したがって完全に独立した sub-package へ分離でき、メイン `Package.swift` は一切変更しない。

> **「library 依存ゼロ」の確認方法（consumer 視点）**: ルートで `swift build` するとメイン package の依存グラフだけが解決され swift-sdk は出現しない（`mcp-swift/` は別パッケージなので巻き込まれない）。`mcp-swift/` 側で `swift build` したときのみ swift-sdk が fetch される。両者のパッケージグラフが交わらないことが分離の成立条件。

#### ターゲット構成

```
mcp-swift/
  Package.swift                              # tools 6.0 / macOS13 / swift-sdk 依存
  Sources/
    TestableUIKitMCPCore/   IPCHelpers.swift # 純関数（外部依存ゼロ・XCTest 対象）
    TestableUIKitMCP/       main.swift       # executable（swift-sdk 依存はここのみ）
  Tests/
    TestableUIKitMCPCoreTests/IPCHelpersTests.swift  # L1 XCTest 41 ケース
```

- `TestableUIKitMCPCore`: host/port 解決・URL 構築・perform payload 組み立て・simctl コマンド生成・loopback 判定。swift-sdk 非依存で機械検証する（Python `ipc_helpers.py` と 1:1）。
- `TestableUIKitMCP`: MCP `Server` に 4 ツールを手動登録し `StdioTransport` で起動。HTTP 中継は `URLSession`。`ui_screenshot` は `GET /screenshot` 一次・loopback のみ simctl フォールバック（Python 版と同一経路）。

#### 起動方法

```bash
# 前提: DemoApp が 実機 / Simulator 上で起動済み（:8888 リッスン中）
cd projects/TestableUIKit/mcp-swift
swift run TestableUIKitMCP
# 接続先上書き: TESTABLE_IPC_HOST=192.168.0.181 swift run TestableUIKitMCP
```

#### 検証状況

- **機械検証済み**: Core 純関数 XCTest 41 green。MCP stdio handshake（`initialize` → `tools/list` で 4 ツール登録確認、`tools/call ui_ping` がアプリ未起動時に `isError` で graceful fail）を実証。
- **VQ/検収レーン**: 実アプリ応答の成功パス（起動中 DemoApp に対する 4 ツール live 駆動のパリティ）は実機/Simulator が前提のため verify-queue へ。

#### Python 版（`mcp_server/`）の廃止条件

両者は当面**併走**し、次を満たした時点で Python 版を撤去する:

1. Swift 版の 4 ツール live 駆動パリティが実機/Simulator で確認できる（VQ クローズ）。
2. CI に `cd mcp-swift && swift test` が組み込まれ green。
3. README / SETUP の起動手順が Swift 版へ一本化される。

廃止までは Python 版が正（live 実証済み）、Swift 版が新（机上＋protocol 検証済み）という位置づけ。

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

### D コード下地（実装済み・2026-06-22）

純コード部分（LAN 越し IPC 対応の前提となるコード変更）を先行実装。
物理ハードウェア・Provisioning・実機ペアリングはスコープ外（Human が後段で実施）。

**サーバー側 `TestableServer` の bind 拡張**:
- `init(port:host:registry:)` に `host` 引数追加（既定 `"127.0.0.1"` = ループバック限定）
- `"0.0.0.0"` 指定で全インターフェース（LAN 公開）に bind
- `NWParameters.requiredLocalEndpoint` でランタイム bind アドレスを制御
- `public let host: String` プロパティとして外部公開
- 後方互換: 既存の `TestableServer(port: 8888, registry: registry)` 呼び出しは引数省略で動作（デグレなし）

**後方互換注意点**: 旧実装は print のみ "localhost" と表示し実際は全インターフェースバインドだった。
本実装でランタイムも loopback 限定（`127.0.0.1`）に統一。接続元は全て localhost 系のため実被害なし。よりセキュアな狭化として意図に合致。

**クライアント側の接続先設定可能化**:
- `ipc_helpers.py`: `resolve_ipc_host_port(env:)` 追加（env 引数で L1 テスト可能な純粋関数）
  - `TESTABLE_IPC_HOST` 環境変数で接続先ホストを上書き（既定: `localhost`）
  - `TESTABLE_IPC_PORT` 環境変数で接続先ポートを上書き（既定: `8888`）
  - 不正なポート文字列は既定値へフォールバック
- `mcp_server/testableui_mcp.py`: 起動時に env から host/port を解決して `_IPC_BASE` を生成
- `Tests/conftest.py` / `run_test.py`: `resolve_ipc_host_port()` 経由で BASE_URL を動的生成

**L1 テスト追加**:
- Swift: `Tests/TestableUIKitTests/TestableServerTests.swift`（10 テスト: 既定値・LAN 公開 host・後方互換）
- Python: `Tests/unit/test_mcp_helpers.py` の `TestResolveIpcHostPort`（13 テスト）
- DoD: `swift test` 96 PASS / pytest unit 42 PASS / commit `7d81160`

**残余（VQ 送り）**: 実機 Wi-Fi 越し実通信の確認（実 iPhone ペアリング後）→ `docs/verify-queue.md` 参照

---

### D 拡張: `ui_screenshot` 実機対応 — provider 注入方式（実装済み・2026-06-23）

**背景**: MCP live PoC（3/4 ツール実機駆動）で `ui_screenshot` のみ `simctl io booted screenshot`（Simulator 専用）依存で実機不可と判明。

**採用方式（経路A）**: アプリ内キャプチャ → IPC 返却。新規エンドポイント `GET /screenshot` を `TestableServer` に追加し、アプリが自身のルート view を PNG レンダリング → base64 で HTTP 返却。`ui_screenshot()` はそのエンドポイントを一次経路として叩くだけにする。

**screenshotProvider 注入設計**:
- `TestableServer(port:host:registry:screenshotProvider:)` に optional な `screenshotProvider: (@MainActor () async -> Data?)?` を追加（既定 nil・後方互換維持）
- `GET /screenshot` は provider を呼び出し base64 化して `{"image_base64":..., "format":"png"}` を返す。未注入時は `{"error":"screenshotProvider not configured"}` を返す（503）
- ライブラリは closure の中身を一切知らない（UIKit 非依存・状態レス維持）
- `DemoApp.swift` が key window キャプチャ closure（`UIGraphicsImageRenderer` ＋ `UIApplication.shared.connectedScenes` ルート view）を生成して注入（UIKit 依存は app 側に閉じる）

**Python 側 `ui_screenshot()` フォールバック戦略**:
- 一次経路: `GET /screenshot`（Simulator/実機共通）
- フォールバック: host が loopback（`127.0.0.1` / `localhost`）かつ `/screenshot` endpoint が 4xx/5xx または接続失敗の場合のみ `simctl io booted screenshot` へ退避（Simulator での後方互換）
- フォールバック判定は純粋関数（`is_loopback_host(host)`、`mcp_server/ipc_helpers.py`）で L1 テスト可能

**L1 テスト追加**:
- Swift: stub provider を注入した `TestableServer` に `GET /screenshot` を叩き、base64 を含む JSON が返ること（4 テスト）
- Python: `build_screenshot_url`・フォールバック判定・passthrough（17 テスト追加）
- DoD: `swift test` 100 PASS / pytest 59 PASS / commit `78716fd`

**残余（VQ 送り）**: 実機（iPhone `192.168.0.181`）への DemoApp 再インストール後、`TESTABLE_IPC_HOST=192.168.0.181` で `ui_screenshot` を呼び実 PNG base64 が取得できるか確認 → `docs/verify-queue.md` 参照

---

## References

- `docs/ipc-protocol.md` — HTTP API specification
- `run_test.py` — Python test runner (Phase A/B examples)
- `DemoApp/LoginButton.swift` — Reference AnyTestable implementation

