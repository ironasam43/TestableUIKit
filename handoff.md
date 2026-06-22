最終更新：2026-06-23（実機 Wi-Fi 越し疎通成立 ＋ MCP live PoC 3/4 ツール実機駆動 ＋ 全 push・CI green）

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

## 現在地：Design D 実機検証クローズ（3/4）→ ui_screenshot の実機対応が残課題

### ✅ 実機 Wi-Fi 越し疎通 ＋ MCP live PoC 完了（2026-06-23）
- 実機（iPhone `192.168.0.181`・DEBUG ビルド `b66a831`・`0.0.0.0:8888` リッスン）に対し:
  - `curl http://192.168.0.181:8888/ping` → `{"status":"ok"}`（Design D 疎通成立・消し込み）
  - MCP tool 関数を `TESTABLE_IPC_HOST=192.168.0.181` で直接駆動 → `ui_ping`/`ui_getState`（count:0）/`ui_perform increment`（count 0→1）/再 getState（count:1）。**MCP→HTTP IPC→実機 UI 変異→describedState 反映の e2e を実機実証**
- **設計ギャップ**: `ui_screenshot` は `simctl io booted`（Simulator 専用）ハードコードで実機不可。VQ 未確認に別行分離（残作業：(a) Simulator 限定で合格扱い／(b) `devicectl` 等で実機対応経路を実装）
- VQ 整備：誤削除されていた Design D ✅ 行を消し込み欄へ復元（commit `1da2d34`）
- **push・CI**: 未 push だった全 8 commit（`5399849`〜`1da2d34`）を push（`a9e1dce..1da2d34`）→ CI run `27989218172` 全3ジョブ success（Build iOS DemoApp / Swift Package Unit Tests / IPC pytest）

## 次ステップ候補
1. **`ui_screenshot` の実機対応（VQ 未確認・筆頭）**: 現状 simctl(Simulator)依存で実機不可。(a) Simulator 限定で合格扱いにするか、(b) `xcrun devicectl` 等で実機スクリーンショット経路を新規実装するか方針決定が必要（verify-queue 参照）
2. **さらに多くのコンポーネント計装**: Picker / DatePicker / List など SwiftUI 標準コンポーネントの拡張
3. **実機ペアリング前提の運用整備**: 実機 IP（`192.168.0.181`）は DHCP で変わりうる。`TESTABLE_IPC_HOST` の設定手順を SETUP/README に明文化すると再現性が上がる

## 🔄 積み残し
- **VQ 未確認 1 件**: `ui_screenshot` 実機未対応（設計ギャップ・上記次ステップ 1）。3/4 ツールは実機 e2e 済み・消し込み
- 実機 `192.168.0.181` は DemoApp（DEBUG `b66a831`・`0.0.0.0:8888`）リッスン中。Mac から `TESTABLE_IPC_HOST=192.168.0.181` で MCP 駆動可能

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
