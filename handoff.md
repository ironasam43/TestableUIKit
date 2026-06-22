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

## 現在地：STEP 2 CI 統合完了 → STEP 3（DX整備）または STEP 2 追加実証へ

### ✅ STEP 2 CI 統合完了（2026-06-22）
- `.github/workflows/ci.yml` の pytest-ipc ジョブに `test_swiftui_counter.py` を追加
- GitHub Actions CI（run #27926198101）で **31 PASS**:
  - `test_ipc.py` 10テスト ✅ / `test_swiftui_counter.py` 21テスト ✅
- Counter IPC（getState/increment/decrement/reset/setProperty/状態遷移）の機械検証完了
- VQ の STEP 2 Counter pytest CI 実行 → 消し込み済み
- **件数ドリフト修正**: 文書記載「30テスト」→ 実体「21テスト」（test_swiftui_counter.py）
- commit: `f3a36ff`、push: `7f5be89..f3a36ff`

### ✅ STEP 2 完了（2026-06-22）：実 SwiftUI コンポーネント計装
- **`Counter` コンポーネント計装完了**（testID: `scene.demo.counter`）：
  - `Sources/TestableUIKit/CounterCore.swift` 新規追加（純粋関数: makeCounterDescribedState / applyIncrement / applyDecrement / applyCounterReset / applyCounterSetProperty）
  - `DemoApp/CounterView.swift` 新規追加（Counter クラス `@MainActor final class Counter: ObservableObject, AnyTestable` ＋ CounterView SwiftUI View）
  - `DemoApp/DemoApp.swift` 修正：`register` に `await` 付与（actor 呼び出し修正）＋ Counter を Registry 登録・ContentView に追加
  - `Tests/test_swiftui_counter.py` 新規追加（21テスト：getState/increment/decrement/reset/setProperty/状態遷移シナリオ）
- **完了ゲート通過**: SPM `swift test` 33 PASS ＋ Xcode iOS Simulator（iPhone 16e）ビルド BUILD SUCCEEDED

### ✅ STEP 1 完了・push 済み（pytest 昇格 / IPC Response schema 確定 / NWConnection 修正）
- `Tests/conftest.py` / `Tests/test_ipc.py` で run_test.py を pytest として正式化（commit `1e42817` / `b0d978d`）
- tap / setProperty の Response schema を確定・`docs/ipc-protocol.md` に明文化（commit `1e42817`）
- TCP ソケットの不完全受信対策修正（commit `7f5be89`）
- **GitHub push 完了**: 上記 3 commit が origin/main に統合済み

## 次ステップ候補
1. **STEP 3（DX整備）**: ViewModifier `@testable(_:)` 抽象化（Design C 本丸）
2. **STEP 2 追加実証**: 3個以上 ＋ Picker/TextField など多様コンポーネント
3. **STEP 1.5 MCP ラッパー化**: Python → Swift 統一化（Design C セクション後追い検討）

## 🔄 積み残し
- **MCP ラッパー化（STEP 1.5）**: Dev/ `docs/test-strategy.md` で差し込み案がレビュー待ち中。採否は別途決定（Design C セクションで後追い検討）

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
