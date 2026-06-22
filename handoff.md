最終更新：2026-06-23（`ui_screenshot` 実機対応 push 済み・CI 全3ジョブ green — Auditor [WARN] 解消（design.md 純関数名を `is_loopback_host` へ整合・commit `5309a5d`）。実装は `78716fd`/docs `11c1238`。残：実機 PNG 取得確認のみ）

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

## 現在地：`ui_screenshot` 実機対応コード実装完了 → DemoApp 再インストール後の実 PNG 取得確認が残タスク

### ✅ `ui_screenshot` 実機対応実装完了（2026-06-23・commit `78716fd`）
- `TestableServer` に `screenshotProvider: (@MainActor () async -> Data?)?` 引数追加（後方互換）＋ `GET /screenshot` エンドポイント追加
- `DemoApp.swift` が `UIGraphicsImageRenderer` ＋ `UIApplication.shared.connectedScenes` でキャプチャする closure を注入（UIKit 依存は app 側に閉じ、ライブラリは状態レス維持）
- `testableui_mcp.py:ui_screenshot()` を `GET /screenshot` 一次経路へ変更（loopback かつ endpoint 不達時のみ simctl フォールバック）
- L1 テスト追加：Swift 4 テスト・pytest 17 テスト（`swift test` 100 PASS / `pytest` 59 PASS）
- `docs/ipc-protocol.md` 追記・`docs/design.md` §D 拡張追記・`docs/history.md` 追記・VQ 更新

## 次ステップ候補
1. **DemoApp 再インストール後の実機 PNG 取得確認（VQ 筆頭）**: 実機（`192.168.0.181`）に `78716fd` ベースの DEBUG ビルドを再インストール → `TESTABLE_IPC_HOST=192.168.0.181` で `ui_screenshot` を呼び PNG base64 取得を確認（VQ 参照）
2. **CI push・CI green 確認**: commit `78716fd` を push して CI 全3ジョブ green を確認
3. **さらに多くのコンポーネント計装**: Picker / DatePicker / List など SwiftUI 標準コンポーネントの拡張
4. **実機ペアリング前提の運用整備**: 実機 IP（`192.168.0.181`）は DHCP で変わりうる。`TESTABLE_IPC_HOST` の設定手順を SETUP/README に明文化すると再現性が上がる

## 🔄 積み残し
- **VQ 未確認 1 件（筆頭）**: `ui_screenshot` の実機での実 PNG 取得確認（DemoApp 再インストール後・`TESTABLE_IPC_HOST=192.168.0.181` で `ui_screenshot` → PNG base64 確認）。実装コード（`78716fd`）は完了済み
- ~~commit `78716fd` は未 push~~ → **push 済み・CI green**（`5309a5d`・run `27990833476` 全3ジョブ success・2026-06-23）

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
