# TestableUIKit：垂直スライス実装

iOS/macOS 向けの UIコンポーネント自己申告型テストフレームワーク。

**差別化：** Swift型システムとAIが融合した、コンポーネント自己申告型テストフレームワーク

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
   cd /Users/koba-p/Documents/Dev/projects/TestableUIKit
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
cd /Users/koba-p/Documents/Dev/projects/TestableUIKit
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

### Q: `[SERVER] Started on...` が表示されない

**A**: DemoApp が Simulator で起動していないか、server.start() が呼ばれていない。

```
Xcode > Console タブで確認
```

### Q: `curl: command not found`

**A**: macOS には curl がデフォルト同梱。PATH 確認：

```bash
which curl
/usr/bin/curl  # このように表示されれば OK
```

### Q: Python test が "Connection refused"

**A**: iOS Simulator が localhost:8888 にリッスンしていない。

```
1. Xcode で Run して Simulator 起動を確認
2. コンソールに [SERVER] メッセージ表示待ち
3. python3 run_test.py 実行
```

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

このプロジェクトは内部開発向けです。

---

## サポート

問題が発生した場合は、Auditor に報告してください。
