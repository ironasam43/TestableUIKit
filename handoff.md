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
- STEP 3 DX整備 ✅（2026-06-22）— **SPM 37 PASS（+4）・ローカルコミット済み・push 待ち**

## 現在地：STEP 3 完了 → push + CI 確認 → 次ステップ選択へ

### ✅ STEP 3 完了（2026-06-22）：`.testable(_:)` ViewModifier 抽象化（Design C ①）
- **`Sources/TestableUIKit/TestableView.swift` 新規追加**:
  - `TestableRegistrationModifier: ViewModifier`（`.task` 内で `await TestableRegistry.shared.register` を自動呼び出し）
  - `View` 拡張 `.testable(_ testable: AnyTestable)`（`@testable import` との命名衝突を回避するメソッド構文を採用）
  - `@available(iOS 15.0, macOS 13.0, *)`
- **`DemoApp/DemoApp.swift` 移行**:
  - Counter の手動 `await TestableRegistry.shared.register(counter)` を削除
  - `CounterView(counter: counter).testable(counter)` に変更（testID `scene.demo.counter` 維持・後方互換）
- **`Tests/TestableUIKitTests/TestableRegistryTests.swift` 新規追加**（L1 DoD ゲート②）:
  - register→find round-trip / 未登録ID→nil / 再登録上書き / describedState の 4ケース
- **`docs/design.md` セクション C 更新**:
  - ① ViewModifier 実装済み（API・予約語回避の経緯）
  - ② EnvironmentObject/Registry 注入は次タスクへ deferred と明記
- **完了ゲート通過**: `swift build` ✅ / `swift test` **37 PASS** ✅ / commit `1b23042`
- **VQ 起票なし**（IPC E2E は CI pytest で機械検証済み）

### ✅ STEP 2 CI 統合完了（2026-06-22）
- `.github/workflows/ci.yml` の pytest-ipc ジョブに `test_swiftui_counter.py` を追加
- GitHub Actions CI（run #27926198101）で **31 PASS**:
  - `test_ipc.py` 10テスト ✅ / `test_swiftui_counter.py` 21テスト ✅
- commit: `f3a36ff`、push: `7f5be89..f3a36ff`

### ✅ STEP 2 完了（2026-06-22）：実 SwiftUI コンポーネント計装
- `Counter` コンポーネント（testID: `scene.demo.counter`）計装済み
- CounterCore.swift / CounterView.swift / test_swiftui_counter.py 追加

### ✅ STEP 1 完了・push 済み
- pytest 昇格 / IPC Response schema 確定 / NWConnection 修正（commit `1e42817`〜`7f5be89`）

## 次ステップ候補
1. **push + CI 確認**: `1b23042` を origin/main へ push → CI pytest 31 維持を確認（STEP 3 の最終確認）
2. **STEP 4（EnvironmentObject 注入）**: グローバルシングルトン廃止・Registry を EnvironmentObject/Environment で View ツリーへ注入（Design C ② deferred）
3. **STEP 2 追加実証**: 3個以上 ＋ Picker/TextField など多様コンポーネント計装
4. **STEP 1.5 MCP ラッパー化**: Python → Swift 統一化

## 🔄 積み残し
- **push 待ち**: commit `1b23042`（STEP 3）を origin/main へ push → Human の明示指示で
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
