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
- **STEP 2 追加実証 — 多様コンポーネント計装** ✅（2026-06-22）— **SPM 86 PASS（+48）・TextInput/OnOffSwitch/RangeSlider 新規計装・pytest E2E 追加・docs 更新**

## 現在地：STEP 2 追加実証 完全クローズ＋CI green 復帰（main green 確定）→ 次ステップ選択へ

### ✅ pytest E2E 回帰 3 連修正 → main green 復帰（2026-06-22）
- `c71bf1a`（STEP 2 追加実証）push 後、新規 pytest E2E（test_swiftui_new_components.py）が CI で red に。初実走の IPC E2E が機械検証として機能し、**3 件のテスト専用バグ**を順次検出・修正（フレームワーク本体は全工程不変）。
  1. `8e5695b`: fixture 3 種（text_input/on_off_switch/range_slider_perform）を counter_perform 契約へ統一（success/state エンベロープ取り違え → 生 describedState dict + raise_for_status）→ 35/37
  2. `0ccf6d4`: `assert_range_slider_state` の expected_keys に `step` 追加（実 describedState は4キー {value,minValue,maxValue,step}）→ 36/37
  3. `20896b1`: `test_range_slider_reset` 期待値を実装の中央値リセットセマンティクス `(maxValue−minValue)/2+minValue`（デフォルト 50）へ修正（テストの minValue 期待が誤り）→ **37 PASS**
- **CI run #17（`27937732375`）success 確定**: pytest **37 passed**（test_ipc 10 + counter 21 + new_components 6）・全3ジョブ success（Build iOS DemoApp / Swift Package Unit Tests / IPC Integration Tests）。
- SPM `swift test` 86 PASS は全工程で不変（本体未変更）。VQ 起票なし（CI pytest で機械検証完結）。
- **教訓**: ローカル swift test では IPC E2E が走らない（常駐サーバ不在）＝ CI 専用レーン。新規 E2E はテスト側の応答契約・期待値ズレが出やすく、CI 初実走が検証の要。



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

## ✅ 実装完了項目
1. **STEP 3/4 push + CI 確認** ✅: commit `1b23042`（STEP 3）＋ `3718c98`（STEP 4）を origin/main へ push → CI pytest 31 PASS 維持（2026-06-22）
2. **STEP 4.5 loginButton ViewModifier 移行** ✅（2026-06-22）: DemoApp.swift の手動 `registry.register(loginButton)` を削除、ContentView の loginButton VStack に `.testable(loginButton)` 付与。Counter と登録方式統一。SPM `swift test` 38 PASS 維持。
3. **STEP 2 追加実証 — 多様コンポーネント計装（TextInput / OnOffSwitch / RangeSlider）** ✅（2026-06-22）:
   - Core 層 3 ファイル新規（TextInputCore / OnOffSwitchCore / RangeSliderCore）+ XCTest 3 ファイル（各 ~14 テスト）
   - DemoApp Views 3 ファイル新規（TextInputView / OnOffSwitchView / RangeSliderView）
   - DemoApp.swift 更新（@StateObject ×3 + ContentView に View + .testable() ×3）
   - pytest E2E 追加（test_swiftui_new_components.py 新規）
   - ci.yml 更新（新規 pytest ファイル追加）
   - docs/design.md・history.md・handoff.md 更新
   - SPM `swift test` **86 PASS** 確認
   - VQ 起票なし（機械検証で完結）
   - **CI 統合完了（2026-06-22）**: 新規 pytest E2E の回帰 3 件（`8e5695b`/`0ccf6d4`/`20896b1`）を修正し CI **37 PASS** green 復帰（run #17 success・上記「現在地」参照）

## 次ステップ候補
1. **さらに多くのコンポーネント計装**: Picker / DatePicker / List など SwiftUI 標準コンポーネントの拡張
2. **STEP 1.5 MCP ラッパー化**: Python → Swift 統一化
3. **実機テスト対応（Design D）**: iOS Simulator から実 iPhone へ拡張

## 🔄 積み残し
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
