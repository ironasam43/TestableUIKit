最終更新：2026-06-24（**semver タグ運用導入・初期 `v0.1.0` タグ起票（inbox 消化・検収不要）**。`main` HEAD に annotated tag `v0.1.0` 付与・remote push 済み（commit `665d464`）。README に「## バージョニング方針（semver）」節を明文化（pre-1.0: MINOR=破壊的/PATCH=互換）。利用側が `.package(from: "0.1.0")` で固定可能に。前回：実機 PNG 取得確認 成立・VQ 全クローズ（未確認 0 件）・実機テスト基盤 4/4 ツール完全クローズ）

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

## 現在地：実機テスト基盤 完全クローズ（4/4 ツール実機 e2e・VQ 未確認 0 件）

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
- **VQ 未確認 0 件**（実機テスト基盤 4/4 ツール完全クローズ・2026-06-23）
- 運用ドキュメント整備（`cac84fe`）＋ Auditor WARN 解消（`d7a2d91`：SETUP.md 7-5 の ui_screenshot 参照パスを mcp_server/testableui_mcp.py へ整合）push 済み・CI run `27994424104` 全3ジョブ green。未 push なし

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
