最終更新：2026-06-26（**課題A: state 宣言型 高レベル API 実装・push 済み（commit `2e4dbac`）**。inbox `2026-06-25-issue-a-state-declarative-api.md`（HQ 発・消化モード: フロー）を消化。Tier1 `TestableComponent<State>`（`TestableProperty` get/set ＋ `runTestablePerform` ＋ Mirror describe フォールバック）と Tier2 drop-in 5種（Toggle/TextField/Stepper/Slider/Button・binding 自動導出）を追加し②AnyTestable 手書き switch を全廃。既存手書き経路は温存（後方互換）。Example 2本（MyToggle を Tier1 へ書き直し / StandardControls 新規）・XCTest +13 → `swift test` 117 PASS。**検収必要のため inbox を done/ へ移動・`sendNote(done)` 送付＝HQ accepted 待ち**。STEP3 タスク5 Bundle ID 確定 → STEP3 全7タスク完走・inbox クローズ。HUMAN 判断で Bundle ID を `dev.plateworks.*` namespace に確定（`project.yml` 2箇所＋`ci.yml` simctl launch）。design.md placeholder ADR を Resolved 化・roadmap STEP3 タスク5 ✅。commit `0c025dc` push 済み。inbox `2026-06-25-step3-distribution-dx.md` 削除。前回：**MCP サーバ B の Swift 化・SPM 公開（inbox 消化・フロー）**。Python 製 `mcp_server/` を独立 sub-package `mcp-swift/`（MCP swift-sdk）へ書き直し。swift-sdk は executable target に封じ込め、メイン `Package.swift` 不変＝library 依存ゼロ・iOS15 完全保全。`swift build` 警告ゼロ・`swift test` 41 PASS・MCP stdio handshake 実証（4 ツール登録確認）。実アプリ live パリティは VQ へ起票（Python 版と併走）。前回：semver `v0.1.0` タグ起票）

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
- STEP 4 TestableRegistry シングルトン廃止・Environment キー注入 ✅（2026-06-22）— **SPM 38 PASS（+1）・push 済み（`3718c98`/`6151ae1`）**
- **STEP 2 追加実証 — 多様コンポーネント計装** ✅（2026-06-22）— **SPM 86 PASS（+48）・TextInput/OnOffSwitch/RangeSlider 新規計装**
- **STEP 1.5 MCP ラッパー化** ✅（2026-06-22）— **4ツール独立 MCP サーバ実装・pytest unit 29 PASS・commit `5399849`**
- **Design D 下地 — LAN 越し IPC コード下地** ✅（2026-06-22）— **SPM 96 PASS（+10）・pytest unit 42 PASS（+13）・commit `7d81160`**
- **STEP D: DemoApp DEBUG 限定 LAN 公開** ✅（2026-06-23）— **`DemoApp/DemoApp.swift` を `#if DEBUG` 分岐で `host: "0.0.0.0"` 指定・SPM 96 PASS 維持・commit `b66a831`**
- **Design D 実機 Wi-Fi 越し疎通成立 ＋ MCP live PoC（3/4 ツール実機駆動）** ✅（2026-06-23）— **実機 iPhone `192.168.0.181` に MCP tool を直接駆動。ui_ping/ui_getState/ui_perform(count 0→1) を実機 e2e 実証・消し込み。ui_screenshot のみ simctl(Simulator)依存で実機不可＝別行で継続。全 8 commit push 済み・CI run `27989218172` 全3ジョブ green**
- **`ui_screenshot` 実機対応実装（経路A: GET /screenshot + screenshotProvider 注入）** ✅（2026-06-23）— **TestableServer に screenshotProvider 注入 + GET /screenshot 追加、DemoApp に UIKit key window キャプチャ closure 注入、Python 側 GET /screenshot 一次経路化＋simctl フォールバック。swift test 100 PASS / pytest 59 PASS / commit `78716fd`。実機での実 PNG 取得確認は VQ へ起票（DemoApp 再インストール後）**

## 現在地：課題A 高レベル API 実装・push 済み（commit `2e4dbac`・HQ 検収待ち）

### ✅ 課題A: state 宣言型 高レベル API（2026-06-26・inbox `2026-06-25-issue-a-state-declarative-api.md` 消化・フロー）
- **目的**: 計装コストの線形増加の犯人＝②AnyTestable 手書き switch ボイラープレートを 2 Tier の高レベル public API で畳む。既存手書き経路は温存（後方互換・回帰なし）。
- **Tier1 `Sources/TestableUIKit/TestableComponent.swift`（新規）**: `TestableProperty<State>`（get/set ＋ `.bool/.int/.double/.string` の WritableKeyPath 便宜コンストラクタ）／共有 `runTestablePerform`（getState/setProperty/commands 表/else unknownCommand throw）／`mirrorDescribe`（describe 省略時に自前値型 stored property を自動 describe・private SwiftUI 型に非接触）／`@MainActor public final class TestableComponent<State>: ObservableObject, AnyTestable`。
- **Tier2 `Sources/TestableUIKit/TestableControls.swift`（新規）**: internal `BindingTestable<Value>` ＋ public View 5種 `TestableToggle`/`TestableTextField`/`TestableStepper`/`TestableSlider`/`TestableButton`（binding 自動導出・registry 自動登録）。
- **サンプル**: `Example/MyToggleExample.swift` を Tier1 へ書き直し（②class 全廃）／`Example/StandardControlsExample.swift` 新規（Tier2 5種）。**テスト**: `TestableComponentTests.swift`（8件）＋ `TestableControlsTests.swift`（5件）。
- DoD: `swift test` **117 PASS（+13）/ 0 failure**。iOS15・library 依存ゼロ維持。DemoApp 不変＝ビルド番号 bump なし。README / docs/getting-started.md に 2 Tier の使い分け追記。
- **状態**: inbox を `inbox/done/` へ移動・`sendNote(done)` 送付済み → **HQ の accepted 待ち**（accepted で ProjectDeck が done/ ファイルを自動削除）。

## 現在地（前）：STEP3 配布・DX 整備 6/7 完了（commit `70f000a` push 済み・Bundle ID のみ HUMAN 判断待ち）

### ✅ STEP3 配布・DX 整備（2026-06-25・inbox `2026-06-25-step3-distribution-dx.md` 消化完了）
- **全7タスク完走・inbox クローズ**。タスク5（Bundle ID）は HUMAN 判断で `dev.plateworks.*` namespace に確定（`project.yml` 2箇所＋`ci.yml` simctl launch・commit `0c025dc` push 済み）。design.md placeholder ADR を Resolved 化・roadmap STEP3 タスク5 ✅。inbox ファイル削除済み。
- `TestableServer.swift`: `State` enum＋`onStateChange`＋`stop()` graceful shutdown 追加。ポート 8888 競合を `.failed` で検知可能化（後方互換維持）。XCTest +4 → **swift test 104 PASS**。
- `docs/getting-started.md`（新規・5分計装ガイド）/ `docs/troubleshooting.md`（独立化）/ `Example/MyToggleExample.swift`（最小サンプル）/ README リンク＋ドキュメント表 / GitHub Release `v0.1.0` 作成 / roadmap STEP3 ✅ 更新。
- DoD: swift 104 PASS / pytest unit 59 PASS（baseline 維持）。タスク5は project.yml/ci.yml/docs のみの変更でロジック不変＝既存 green 維持。
- 補足: STEP2「SwiftUI 非対応」ドリフトは project 側 roadmap には不在（既に ✅ 表記）。当該表記は `Dev/docs/test-strategy.md` §7（スコープ外）→ 必要なら Dev/ 側で修正。

## 現在地（前）：実機テスト基盤 完全クローズ（4/4 ツール実機 e2e・VQ 未確認 0 件）

### ✅ `ui_screenshot` 実機 PNG 取得確認 成立（2026-06-23・検証のみ・コード変更なし）
- 最新 DEBUG ビルド（`05f03b7` ベース・`GET /screenshot` 搭載）を実機 `192.168.0.181` へ再インストール・起動済み
- Mac から `TESTABLE_IPC_HOST=192.168.0.181 .venv/bin/python` で実コード `ui_screenshot()` 直接駆動 → `format:"png"`・base64 106,360 文字 → デコード後 **79,768 bytes・PNG シグネチャ一致・960×1440**
- 経路A（`GET /screenshot` アプリ内キャプチャ）が Simulator 非依存で実機動作することを実証 → `ui_ping`/`ui_getState`/`ui_perform`/`ui_screenshot` の **4/4 ツールが実機 e2e でクローズ**
- VQ 最後の未確認 1 件を消し込み（未確認 0 件）

### ✅ `ui_screenshot` 実機対応実装完了（2026-06-23・commit `78716fd`）
- `TestableServer` に `screenshotProvider: (@MainActor () async -> Data?)?` 引数追加（後方互換）＋ `GET /screenshot` エンドポイント追加
- `DemoApp.swift` が `UIGraphicsImageRenderer` ＋ `UIApplication.shared.connectedScenes` でキャプチャする closure を注入（UIKit 依存は app 側に閉じ、ライブラリは状態レス維持）
- `testableui_mcp.py:ui_screenshot()` を `GET /screenshot` 一次経路へ変更（loopback かつ endpoint 不達時のみ simctl フォールバック）
- L1 テスト追加：Swift 4 テスト・pytest 17 テスト（`swift test` 100 PASS / `pytest` 59 PASS）
- `docs/ipc-protocol.md` 追記・`docs/design.md` §D 拡張追記・`docs/history.md` 追記・VQ 更新

## 次ステップ候補
1. **さらに多くのコンポーネント計装**: Picker / DatePicker / List など SwiftUI 標準コンポーネントの拡張
2. ✅ **実機ペアリング前提の運用整備** （2026-06-23）: 実機 IP・DHCP 変動・`TESTABLE_IPC_HOST` 設定手順を SETUP.md ステップ7 ＋ README.md サブ節に明文化。再現性向上・整備完了
3. ✅ **screenshot 経路の整理** （2026-06-23）: 実機=`GET /screenshot`・Simulator=simctl フォールバックの二経路を SETUP.md ステップ7 ＋ README.md に明文化。経路選択ルール・混乱防止・整備完了

## 🔄 積み残し
- **課題A 検収待ち**: inbox `inbox/done/2026-06-25-issue-a-state-declarative-api.md`・`sendNote(done)` 送付済み。HQ が API 形・②削減効果を裏取りして accepted/rejected を返す。accepted で done/ 自動削除。
- **申し送り（Swift 6 言語モード・非ブロッキング）**: 課題Aの `@MainActor` generic class（`TestableComponent<State>`/`BindingTestable<Value>`）の `AnyTestable` 準拠に language mode 5.9 で `#ConformanceIsolation` 警告（Swift 6 言語モードではエラー化）。5.9 では警告止まりで build/test 非ブロック。将来 Swift 6 へ上げる際は `CLIDemoLoginButton` 同様の `@unchecked Sendable`+`NSLock` パターンへ寄せる検討が必要。
- ~~STEP3 タスク5（Bundle ID）~~ ✅ 完了（`dev.plateworks.*` 確定・inbox クローズ）。**注意**: bundle ID 変更後の `xcodegen generate`＋実機/Simulator への再インストールは未実施（`*.xcodeproj` は git 非追跡で再生成のため、次回ビルド時に自動反映される）。CI は simctl launch ターゲットを更新済み。
- **VQ 未確認 1 件**（2026-06-24 起票）: MCP Swift 版（`mcp-swift/`）の 4 ツール live パリティ（起動中 DemoApp に対する実 HTTP 中継成功パス）を実機/Simulator で確認。protocol-level＋Core 純関数 41 XCTest は機械検証済み。合格で Python 版 `mcp_server/` 廃止条件①を満たす。
- **Python 版 `mcp_server/` は併走中**。廃止条件＝①live パリティ確認（VQ）②CI に `cd mcp-swift && swift test` 組込 green ③README/SETUP 起動手順を Swift 版へ一本化。`docs/design.md` §E2 参照。
- **CI 未配線**: `mcp-swift/` の `swift test` は手元のみ。`.github/workflows/ci.yml` への組込は次タスク候補（廃止条件②）。
- 運用ドキュメント整備（`cac84fe`）＋ Auditor WARN 解消（`d7a2d91`）push 済み・未 push なし

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
