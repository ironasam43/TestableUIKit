最終更新：2026-06-22（Design D 下地 — LAN 越し IPC コード下地 完了）

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

## 現在地：Design D 下地 完了 → 実機ペアリング待ち

### ✅ Design D 下地 完了（2026-06-22）
**TestableServer の bind ホスト指定 + クライアント接続先の環境変数上書き**

- `Sources/TestableUIKit/TestableServer.swift`:
  - `init` に `host: String = "127.0.0.1"` 引数追加（後方互換）
  - `NWParameters.requiredLocalEndpoint` で bind アドレスを制御（127.0.0.1=loopback / 0.0.0.0=全インターフェース）
  - `public let host: String` プロパティとして外部公開
  - `start()` の print 文を `host:port` 反映に修正
- `mcp_server/ipc_helpers.py`:
  - `resolve_ipc_host_port(env:)` 純粋関数追加（env 引数でテスト可）
  - `TESTABLE_IPC_HOST` / `TESTABLE_IPC_PORT` 環境変数で接続先上書き可
  - `ENV_IPC_HOST` / `ENV_IPC_PORT` 定数追加
- `mcp_server/testableui_mcp.py`: `resolve_ipc_host_port()` で `_IPC_BASE` を動的生成
- `Tests/conftest.py`: `BASE_URL` を `resolve_ipc_host_port()` 経由に変更
- `run_test.py`: `IPC_BASE_URL` を `resolve_ipc_host_port()` 経由に変更
- `Tests/TestableUIKitTests/TestableServerTests.swift`（新規 10 テスト）
- `Tests/unit/test_mcp_helpers.py`（`TestResolveIpcHostPort` +13 テスト）
- `docs/design.md` §D「コード下地（実装済み）」セクション追記
- `docs/verify-queue.md` に「実機 Wi-Fi 越し実通信確認」起票
- **DoD**: `swift test` 96 PASS / pytest unit 42 PASS / commit `7d81160`（未 push）

## 次ステップ候補
1. **さらに多くのコンポーネント計装**: Picker / DatePicker / List など SwiftUI 標準コンポーネントの拡張
2. **MCP live PoC 駆動実証（VQ）**: Simulator + DemoApp 起動 → `ui_ping`/`ui_getState`/`ui_perform`/`ui_screenshot` 4ツール疎通確認（verify-queue 参照）
3. **実機テスト対応（Design D）**: コード下地 完了・実機ペアリング待ち（Provisioning Profile・デバイス UUID 登録・signing は Human が実施）

## 🔄 積み残し
（なし）

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
