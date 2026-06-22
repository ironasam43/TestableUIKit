最終更新：2026-06-23（STEP D: DemoApp DEBUG 限定 LAN 公開 完了）

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

## 現在地：STEP D 完了 → 実機再インストール・Wi-Fi 越し疎通確認待ち

### ✅ STEP D: DemoApp DEBUG 限定 LAN 公開 完了（2026-06-23）
**`DemoApp/DemoApp.swift` の `#if DEBUG` 分岐実装**

- `DemoApp/DemoApp.swift`:
  - `#if DEBUG` ブロック内で `TestableServer(port: 8888, host: "0.0.0.0", registry: registry)` を使用
  - `#else`（Release）は従来の `TestableServer(port: 8888, registry: registry)`（既定 127.0.0.1）を維持
  - ライブラリ API は変更不要（Design D 下地で実装済みの `host:` 引数を活用）
- セキュリティ設計意図：Release ビルドで loopback に限定し、App Store 配布時の意図しない LAN 露出を防止
- **DoD**: `swift build` PASS / `swift test` 96 PASS（回帰なし）/ commit `b66a831`（`wip:` 未 push）
- `docs/verify-queue.md` の「Design D — 実機 Wi-Fi 越し実通信確認」起票に具体的な IP（`192.168.0.181`）と検証手順を追記

## 次ステップ候補
1. **さらに多くのコンポーネント計装**: Picker / DatePicker / List など SwiftUI 標準コンポーネントの拡張
2. **MCP live PoC 駆動実証（VQ）**: Simulator + DemoApp 起動 → `ui_ping`/`ui_getState`/`ui_perform`/`ui_screenshot` 4ツール疎通確認（verify-queue 参照）
3. **実機テスト対応（Design D）**: DEBUG LAN 公開 実装済み（`b66a831`）・Human が実機へ DEBUG ビルドを再インストール後、Mac 側で `export TESTABLE_IPC_HOST=192.168.0.181` を設定して `ui_ping` / `ui_getState` 等の疎通確認を実施（verify-queue 参照）

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
