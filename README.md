# TestableUIKit

iOS/macOS 向けの UIコンポーネント自己申告型テストフレームワーク。

**差別化：** Swift 型システムと AI（MCP: Model Context Protocol）が融合した、コンポーネント自己申告型テストフレームワーク。UI コンポーネントが `testID`・状態・実行可能コマンドを自己申告し、AI エージェントが MCP 経由で実行中の UI を直接操作・検証できる。

> 🚀 **はじめての方へ**: 自作コンポーネントを 5 分で計装する手順は
> [`docs/getting-started.md`](docs/getting-started.md) を参照してください。
> 最小の動くサンプルは [`Example/`](Example/README.md)、困ったときは
> [`docs/troubleshooting.md`](docs/troubleshooting.md) にまとまっています。

---

## AI エージェントによる自動操作（MCP）

TestableUIKit は [MCP（Model Context Protocol）](https://modelcontextprotocol.io/) サーバー（[`mcp-swift/`](mcp-swift/)）を同梱しており、Claude などの AI エージェントが Claude Desktop / Claude Code から stdio 経由で接続し、実行中の UI を直接操作・検証できます。**探索的な AI 駆動**と**決定的な宣言的シナリオ**の二つのアプローチを両輪で提供します。

### 1. AI 動的シナリオ（探索的）

AI エージェントが `ui_getState` で現在の状態を取得 → 自ら判断 → `ui_perform` でコマンド実行 → `ui_screenshot` で見た目を確認、というサイクルを都度の判断で連鎖させながら UI を探索的に操作・検証します。仕様が固まっていない画面の探索や、想定外の挙動の調査に向いています。

### 2. 宣言的シナリオ（`ui_runScenario`・決定的）

操作列と期待値をあらかじめ JSON で定義しておき、1 回の MCP 呼び出しで先頭から順に実行し、各ステップの `describedState` を `expect` と突合して pass/fail を判定します。AI の都度判断を介さず決定的に実行できるため、回帰確認に向いています。

```json
{
  "name": "counter-flow",
  "steps": [
    { "action": "getState", "testID": "scene.demo.counter", "expect": { "count": 0 } },
    { "action": "increment", "testID": "scene.demo.counter", "expect": { "count": 1 } }
  ]
}
```

動作するサンプルは [`Example/scenarios/`](Example/scenarios/) を参照してください。

### MCP ツール一覧（5 本）

| ツール | ラップ先 | 用途 |
|---|---|---|
| `ui_ping` | `GET /ping` | サーバー死活確認 |
| `ui_getState(testID)` | `POST /perform` getState | 状態取得 |
| `ui_perform(testID, command, params)` | `POST /perform` | コマンド実行（tap / setProperty / setEnabled など） |
| `ui_screenshot` | `GET /screenshot`（simctl フォールバック） | スクリーンショット取得 |
| `ui_runScenario(scenario)` | `POST /perform` を複数ステップぶん順送り | 宣言的 JSON シナリオの実行・assert 判定 |

### 起動方法

```bash
cd mcp-swift
swift run TestableUIKitMCP
```

Claude Desktop / Claude Code などの MCP クライアント設定に stdio サーバーとして登録してください。プロトコル詳細は [`docs/ipc-protocol.md`](docs/ipc-protocol.md)・[`docs/design.md`](docs/design.md) §E を参照。

---

## 計装の 3 段階（API Tiers）

抽象度の異なる 3 段階の API があります。**まず上から検討**し、合わなければ下に降りてください。

| Tier | API | 向いている対象 | 必要な部品 |
|---|---|---|---|
| **Tier 2** | `TestableToggle` / `TestableTextField` / `TestableStepper` / `TestableSlider` / `TestableButton` | 標準 SwiftUI コントロール | View を差し替えるだけ |
| **Tier 1** | `TestableComponent<State>` | 自作コンポーネント（state 値型を持つ） | state 値型 ＋ `properties` / `commands` の宣言（手書き `perform` 不要） |
| **Tier 0** | `AnyTestable` 手書き準拠 | 特殊計装（ロック制御・cross-process 等） | `testID` / `describedState` / `perform` を自前実装 |

```swift
// Tier 2: 標準コントロールは View を差し替えるだけ
TestableToggle("通知", isOn: $isOn, id: "settings.toggle")

// Tier 1: 自作 state は TestableComponent を宣言するだけ（ブリッジ class 不要）
TestableComponent<MyToggleState>(
  id: "example.my.toggle",
  state: MyToggleState(),
  properties: ["isOn": .bool(\.isOn)],
  commands: ["toggle": { s, _ in s.isOn.toggle() }]
)
```

詳しい使い分けは [`docs/getting-started.md`](docs/getting-started.md) の「3 つの API 段階」を参照してください。

---

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [`docs/getting-started.md`](docs/getting-started.md) | 5 分で自作コンポーネントを計装する手順 |
| [`Example/`](Example/README.md) | 自分のコンポーネントをテストする最小サンプル |
| [`docs/ipc-protocol.md`](docs/ipc-protocol.md) | IPC プロトコル仕様 |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | トラブルシューティング |
| [`SETUP.md`](SETUP.md) | Xcode セットアップ手順（実機含む） |
| [`docs/design.md`](docs/design.md) | 設計・アーキテクチャ |

---

## プロジェクト構成

```
TestableUIKit/
├── Sources/TestableUIKit/          # Swift Library（コア実装）
│   ├── JSONValue.swift             # JSON値の型定義（Codable）
│   ├── AnyTestable.swift           # @MainActor protocol
│   └── TestableServer.swift        # Registry + HTTP handler
├── Package.swift                   # Swift Package 定義
├── run_test.py                     # Python テストランナー（Phase A/B）
├── DemoApp-iOS-template.swift      # iOS App テンプレート（SwiftUI）
├── LoginButton-iOS-template.swift  # UIButton実装テンプレート
├── SETUP.md                        # Xcode セットアップ手順
└── README.md                       # このファイル
```

---

## アーキテクチャ

### 層構成

```
┌────────────────────────────────────────────────┐
│ iOS Simulator / 実機（DemoApp）                 │
│ ┌──────────────────────────────────────────┐  │
│ │ LoginButton (AnyTestable)                 │  │
│ │ - testID: "auth.loginButton"              │  │
│ │ - describedState: [String: JSONValue]    │  │
│ │ - perform(commandName, parameters)       │  │
│ └──────────────────────────────────────────┘  │
│ ┌──────────────────────────────────────────┐  │
│ │ TestableRegistry (shared)                │  │
│ │ - register(testable: AnyTestable)        │  │
│ │ - testable(for: testID) → AnyTestable?  │  │
│ └──────────────────────────────────────────┘  │
│ ┌──────────────────────────────────────────┐  │
│ │ TestableServer (@MainActor)              │  │
│ │ - start() async throws                   │  │
│ │ - handleRequest(...) → (status, body)   │  │
│ └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
          HTTP localhost:8888
          ↓        ↑
      /ping    /perform
          ↓        ↑
┌────────────────────────────────────────────────┐
│ Python Test Runner（run_test.py）              │
│ - Phase A: curl GET /ping                      │
│ - Phase B: curl POST /perform (tap command)   │
│ - Assert: response JSON contains expected state│
└────────────────────────────────────────────────┘
```

### データフロー

1. **iOS App 起動**：DemoApp が TestableServer.start() を呼び出し
2. **Registry に登録**：LoginButton が TestableRegistry に自動登録
3. **テスト実行**：Python スクリプトが HTTP POST で commands を送信
4. **状態取得**：perform() が実行され、describedState が JSON で返却
5. **検証**：Python がレスポンス JSON をアサート

---

## コンポーネント仕様

### AnyTestable protocol

```swift
@MainActor
protocol AnyTestable: AnyObject {
  var testID: String { get }
  var describedState: [String: JSONValue] { get }
  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue]
}
```

**責務**：
- `testID`：一意識別子（e.g., "auth.loginButton"）
- `describedState`：現在の論理状態（JSON compatible）
- `perform()`：コマンド実行→新状態を返す

### JSONValue enum

6ケースのプリミティブ値（JSON 互換）：

```swift
enum JSONValue: Codable, Hashable, Sendable {
  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  indirect case object([String: JSONValue])
}
```

拡張メソッド：
- `.toJSON: Any`：JSON シリアライゼーション
- `.asBool`, `.asString`, `.asInt`, `.asDouble`, `.asObject`：型キャスト

### LoginButton: UIButton

テスト対象コンポーネント：

```swift
class LoginButton: UIButton, AnyTestable {
  let testID = "auth.loginButton"
  
  var describedState: [String: JSONValue] {
    ["isEnabled": .bool(isEnabled), "title": .string(title ?? "Log In")]
  }
  
  func perform(commandName: String, parameters: JSONValue) async -> [String: JSONValue] {
    switch commandName {
    case "tap": sendActions(for: .touchUpInside); return describedState
    case "setEnabled": /* enable/disable */ return describedState
    default: throw TestableError.unknownCommand(commandName)
    }
  }
}
```

---

## 使用方法

### セットアップ（初回のみ）

**前提条件**:
- Xcode 15+
- xcodegen 2.45.3+ （インストール: `brew install xcodegen`）
- Python 3.8+

**手順**:

1. **project.yml から xcodeproj を生成**：
   ```bash
   cd TestableUIKit  # リポジトリのルート
   xcodegen generate
   ```

2. **Simulator で実行**：
   ```bash
   xcodebuild \
     -project TestableUIKitDemo.xcodeproj \
     -scheme TestableUIKitDemo \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
     build
   ```

   または Xcode GUI：
   ```
   Xcode > Product > Run
   ```

**注意**：
- `TestableUIKitDemo.xcodeproj/` は `.gitignore` で除外されています（自動生成物）
- `project.yml` が真実のソース。修正がある場合は `project.yml` を編集後 `xcodegen generate` を実行してください

### テスト実行

```bash
# 別ターミナルで
cd TestableUIKit  # リポジトリのルート
python3 run_test.py
```

**出力例**：

```
[PHASE A] Network Path Verification
...
✅ [PASS] Server is reachable

[PHASE B] Logic Verification - Tap LoginButton
...
✅ [PASS] Tap command successful
   Response: {"isEnabled": true, "title": "Log In"}

All tests completed successfully!
```

### 実機（LAN 越し）での実行

Simulator ではなく実機の iPhone / iPad でテストを実行する場合：

```bash
# 実機の IP アドレスを指定してテスト実行
TESTABLE_IPC_HOST=<実機IP> python3 run_test.py
```

**例**（実機の IP が `192.168.0.181` の場合）：
```bash
TESTABLE_IPC_HOST=192.168.0.181 python3 run_test.py
```

詳細は **[SETUP.md のステップ 7](./SETUP.md#ステップ-7実機lan-越しでの実行)** を参照してください（IP 確認方法・ファイアウォール設定・トラブルシューティングを記載）。

---

## 技術スタック

| レイヤー | 技術 | バージョン |
|---|---|---|
| **Swift Runtime** | Swift 5.9+ | iOS 15+ |
| **HTTP Framework** | 標準ライブラリ（URLSession） | — |
| **Async/Await** | Swift Concurrency | — |
| **Build Tool** | xcodegen | 2.45.3+ |
| **Package Manager** | SPM | — |
| **Test Framework** | Python 3.8+ | — |
| **HTTP Client** | curl | — |

---

## 次のフェーズ（バックログ）

- [ ] Contract（仕様）の追加：Invariant + Transition
- [ ] スクリーンショット + 変化分析
- [ ] AI テスト生成（GPT-4 / Claude）
- [x] 実機対応（Wi-Fi 越し LAN 通信）✅
- [ ] CI/CD 統合（GitHub Actions）

---

## Troubleshooting

トラブルシューティングは [`docs/troubleshooting.md`](docs/troubleshooting.md) に独立化しました。
サーバ起動・接続、ポート 8888 競合、Registry 共有もれ、実機（LAN 越し）、Python ランナーなどの
対処を網羅しています。

---

## バージョニング方針（semver）

本ライブラリは [Semantic Versioning](https://semver.org/lang/ja/) に従ってタグを付与する。
利用側は `.package(url: "https://github.com/ironasam43/TestableUIKit", from: "0.1.0")` のように
バージョン固定できる。

### pre-1.0（現在）の運用ルール

公開 API は安定化前（`0.x`）であり、**破壊的変更を許容する段階**にある。
`0.x` 系では semver の慣例に従い、以下の粒度でタグを切る:

| 変更種別 | 上げる桁 | 例 |
|---|---|---|
| 破壊的変更（公開 API のシグネチャ変更・削除） | MINOR | `0.1.0` → `0.2.0` |
| 後方互換な機能追加・バグ修正 | PATCH | `0.1.0` → `0.1.1` |

> `0.x` では MINOR が「破壊的変更」を、PATCH が「互換変更」を表す（1.0 到達後の MAJOR/MINOR に相当）。

### タグを切るタイミング

- 公開 API（`TestableUIKit` ライブラリの export シンボル）に変更が入り、利用側に配布したい節目で annotated tag を切る。
- 内部実装のみの変更（テスト・ドキュメント・Demo アプリ）はタグ不要。
- タグは `git tag -a vX.Y.Z -m "..."` で annotated tag として作成し、`git push origin vX.Y.Z` で remote へ反映する。

### 1.0 到達条件（将来）

公開 API（IPC プロトコル・`AnyTestable` protocol・MCP tool 群）が安定し、破壊的変更を避ける段階に入ったら `v1.0.0` を切る。

---

## ライセンス

ライセンスは現在検討中です（LICENSE ファイル追加時に確定します）。利用を検討される場合はリポジトリの Issue でお問い合わせください。

---

## サポート

問題や質問がある場合は、[GitHub Issues](https://github.com/ironasam43/TestableUIKit/issues) で報告してください。
