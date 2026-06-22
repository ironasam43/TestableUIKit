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

## 現在地：STEP 2 完了 → STEP 3（DX整備）または STEP 2 追加実証へ

### ✅ STEP 2 完了（2026-06-22）：実 SwiftUI コンポーネント計装
- **`Counter` コンポーネント計装完了**（testID: `scene.demo.counter`）：
  - `Sources/TestableUIKit/CounterCore.swift` 新規追加（純粋関数: makeCounterDescribedState / applyIncrement / applyDecrement / applyCounterReset / applyCounterSetProperty）
  - `DemoApp/CounterView.swift` 新規追加（Counter クラス `@MainActor final class Counter: ObservableObject, AnyTestable` ＋ CounterView SwiftUI View）
  - `DemoApp/DemoApp.swift` 修正：`register` に `await` 付与（actor 呼び出し修正）＋ Counter を Registry 登録・ContentView に追加
  - `Tests/test_swiftui_counter.py` 新規追加（30テスト：getState/increment/decrement/reset/setProperty/状態遷移シナリオ）
- **完了ゲート通過**: SPM `swift test` 33 PASS ＋ Xcode iOS Simulator（iPhone 16e）ビルド BUILD SUCCEEDED
- **未 push**（ローカルコミット済み）

### ✅ STEP 1 完了・push 済み（pytest 昇格 / IPC Response schema 確定 / NWConnection 修正）
- `Tests/conftest.py` / `Tests/test_ipc.py` で run_test.py を pytest として正式化（commit `1e42817` / `b0d978d`）
- tap / setProperty の Response schema を確定・`docs/ipc-protocol.md` に明文化（commit `1e42817`）
- TCP ソケットの不完全受信対策修正（commit `7f5be89`）
- **GitHub push 完了**: 上記 3 commit が origin/main に統合済み

## 次ステップ候補
1. **STEP 2 CI 統合**（push ＋ CI で test_swiftui_counter.py 実行）: シミュレータ上の Counter コンポーネントに対して pytest 30テスト が CI で PASS することを確認
2. **STEP 3（DX整備）**: ViewModifier `@testable(_:)` 抽象化（Design C 本丸）
3. **STEP 2 追加実証**: 3個以上 ＋ Picker/TextField など多様コンポーネント
4. **STEP 1.5 MCP ラッパー化**: Python → Swift 統一化（Design C セクション後追い検討）

## 🔄 積み残し
- **MCP ラッパー化（STEP 1.5）**: Dev/ `docs/test-strategy.md` で差し込み案がレビュー待ち中。現行 pytest ベースで STEP 2 完了済み。採否は別途決定（Design C セクションで後追い検討）
- **STEP 2 pytest CI 実行検証**: `test_swiftui_counter.py` の CI ジョブ追加は未実施（ローカルビルドのみ）。CI push で probe-simulator job がどう対応するか要確認。
