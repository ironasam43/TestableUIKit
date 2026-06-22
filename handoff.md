最終更新：2026-06-22

# TestableUIKit 作業メモ

> 過去の詳細ログは `handoff_1.md`（退避済み）、マイルストーン要約は `docs/history.md` を参照。

## プロジェクト概要
- iOS UI コンポーネントが自己申告型で HTTP IPC（localhost:8888）を通じてテスト可能になるフレームワーク
- 構成：Swift Package（Library: TestableUIKit）＋ CLI executable（TestableUIKitDemo）＋ iOS App（DemoApp）
- ビルド管理：xcodegen（`project.yml` が宣言的ソース。`*.xcodeproj` は git 非追跡で再生成）

## 完了済みマイルストーン
- M-1 IPC層検証 ✅ / M-2 iOS App UI連動 ✅ / M-3a xcodegen 移行 ✅
- M-3-0 git cleanup ✅ / M-3-1 OS·device matrix 確定（iOS 16.0 / iPhone 16 + iPad Air）✅ / M-3-3 CI/CD 統合 ✅
- M-4 setProperty 拡張（isEnabled/title/isHidden/alpha/backgroundColor）✅ — **合計 23 tests PASS**
- STEP 1 pytest 昇格 / IPC Response schema 確定 / NWConnection 修正 ✅ — **CI 全3ジョブ PASS・push 済み**
- STEP 2 実 SwiftUI コンポーネント計装 ✅（Counter）— **SPM 33 PASS・CI push 済み**
- STEP 2 CI 統合 ✅（2026-06-22）— **CI pytest 31 PASS（test_ipc.py 10 + test_swiftui_counter.py 21）**
- STEP 3 DX整備 ✅（2026-06-22）— **SPM 37 PASS（+4）・push 済み（`1b23042`/`70eee1d`）**
- STEP 4 TestableRegistry シングルトン廃止・Environment キー注入 ✅（2026-06-22）— **SPM 38 PASS（+1）・push 済み（`3718c98`/`6151ae1`、`70eee1d..6151ae1`）・CI pytest 31 PASS**

## 現在地：STEP 4 完全クローズ（push 済み・CI PASS）→ 次ステップ選択へ

### ✅ STEP 4 完了（2026-06-22）：TestableRegistry シングルトン廃止・Environment キー注入（Design C ②）
- **`Sources/TestableUIKit/AnyTestable.swift`**:
  - `static let shared` 削除・`init()` を `public` 化（シングルトン廃止）
- **`Sources/TestableUIKit/TestableEnvironment.swift` 新規追加**:
  - `TestableRegistryKey: EnvironmentKey` + `EnvironmentValues.testableRegistry` 拡張
  - `@available(iOS 15.0, macOS 13.0, *)`
  - defaultValue リスク（注入忘れで silent failure）を注釈付きで明記
- **`Sources/TestableUIKit/TestableServer.swift`**:
  - `private let registry: TestableRegistry` 追加
  - `init(port:registry:)` で Registry を注入保持（引数必須化）
  - `handle` の `TestableRegistry.shared.find` → `registry.find` へ変更
- **`Sources/TestableUIKit/TestableView.swift`**:
  - `@Environment(\.testableRegistry) private var registry` 追加
  - `.task` 内を `registry.register(testable)` へ変更（Environment 経由）
- **`DemoApp/DemoApp.swift`**:
  - `@State private var registry = TestableRegistry()` を RootView に追加
  - `.environment(\.testableRegistry, registry)` で ContentView 配下全体へ注入
  - `.task` 内で `TestableServer(port: 8888, registry: registry)` 注入・loginButton を直接 register
- **`Sources/TestableUIKitDemo/main.swift`**（CLI）:
  - `let registry = TestableRegistry()` をローカル生成
  - `TestableServer(port: 8888, registry: registry)` で注入
- **`Tests/TestableUIKitTests/TestableRegistryTests.swift`**:
  - 全テストを `.shared` → `TestableRegistry()` ローカルインスタンス生成へ改修
  - `testMultipleInstancesAreIsolated`（複数インスタンス隔離実証）を新規追加
- **`docs/design.md` セクション C ② 更新**:
  - 「次タスクへ deferred」→「STEP 4 実装済み」へ更新
  - EnvironmentObject 非採用理由（actor と ObservableObject の非互換）を明記
  - 注入アーキテクチャ（DemoApp / CLI の違い）・defaultValue リスクを記述
- **完了ゲート通過**: `swift build` ✅ / `swift test` **38 PASS** ✅ / commit `3718c98`
- **VQ 起票なし**（変更は全て SPM テスト＋CI pytest で機械検証可能）

### ✅ STEP 3 完了（2026-06-22）：`.testable(_:)` ViewModifier 抽象化（Design C ①）
- `Sources/TestableUIKit/TestableView.swift` 新規追加（STEP 4 で改修済み）
- `DemoApp/DemoApp.swift` 移行（Counter の手動 register → `.testable(counter)`）
- `Tests/TestableUIKitTests/TestableRegistryTests.swift` 新規追加（STEP 4 で改修済み）
- commit `1b23042`（STEP 3）＋ `3718c98`（STEP 4）がローカルにある

### ✅ STEP 2 CI 統合完了（2026-06-22）
- CI pytest **31 PASS**（test_ipc.py 10 + test_swiftui_counter.py 21）
- commit: `f3a36ff`、push: `7f5be89..f3a36ff`（push 済み）

## 次ステップ候補
1. **push + CI 確認**: commit `1b23042`（STEP 3）＋ `3718c98`（STEP 4）を origin/main へ push → CI pytest 31 維持を確認
2. **STEP 2 追加実証**: 3個以上 ＋ Picker/TextField など多様コンポーネント計装
3. **loginButton を `.testable()` ViewModifier へ移行**: DemoApp.swift の手動 `registry.register(loginButton)` を ViewModifier 化（STEP 4 スコープ外として分離済み）
4. **STEP 1.5 MCP ラッパー化**: Python → Swift 統一化

## 🔄 積み残し
- ~~push 待ち~~ ✅ 解消（2026-06-22）: STEP 3/4 全コミット push 済み（`6151ae1` まで）・CI run #27928282529 全3ジョブ PASS・pytest 31 維持
- **MCP ラッパー化（STEP 1.5）**: Dev/ `docs/test-strategy.md` で差し込み案がレビュー待ち中。採否は別途決定

---

## 教訓索引（lessons.md 見出し）
全文: docs/lessons.md
- 2026-06-04: 修正対象ファイルを確認せず誤ファイルを複数回変更
- 2026-06-13: トランスクリプト末尾を「現在地」と誤読する罠
- 2026-06-14: 確認なしでプロジェクト固有 CLAUDE.md に書いた
- 2026-06-15: 注入スニペットだけ見て handoff「空」と断定
- 2026-06-18: VQ 起票ルールを「再修正だから」と自己正当化して逸脱
- 2026-06-19: 未実行のツール出力を「実行済み」と捏造した
- 2026-06-19: HQ の越境は OK・違反は「DoD 飛ばし」と「事後報告」
- 2026-06-19: cd でリポを跨ぎ相対パスの grep が別リポを読んだ
