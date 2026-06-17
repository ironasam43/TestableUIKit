最終更新：2026-06-18

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

## 現在地：STEP 1 完了・push 済み ✅ → STEP 2（実 SwiftUI コンポーネント計装）へ

### ✅ 完了済み
- Phase 0 PoC `probe-simulator` job 修正完了（commit `5de08ca` + `0f23586`）
  - commit `5de08ca`：`--terminate-running-process` フラグ追加、process check を `launchctl list | grep com.testable.TestableUIKitDemo` に修正
  - commit `0f23586`：iPhone UDID での正確なデバイス選択（.name → .udid、startswith("iPhone") フィルタ）、bootstatus コマンドから非存在オプション `--timeout 300` を削除
  - **CI 全3ジョブ ✅ PASS**: Swift Package Unit Tests / Build iOS DemoApp / Phase 0 PoC - Simulator Boot, App Launch & Loopback
- 実 API 仕様を `run_test.py` 全行照合で確定：
  - `GET /ping` → `{"status":"ok"}`
  - `POST /perform` body: `{"testID","commandName":"getState"|"tap"|"setProperty","parameters":{}|{"key","value"}}`
  - 単独エンドポイント（/setProperty 等）は存在しない。すべて `POST /perform` で discriminate
  - Response schema 確定済み（getState / tap / setProperty とも）→ `docs/ipc-protocol.md` に明文化
- **実用化ロードマップを正式ドキュメント化** ✅
  - `docs/roadmap.md` 新規作成：実用化の定義、現在地（到達済み）、4ステップ（STEP 1-4）、推奨ルートを明文化
  - STEP 1（テストランナー昇格）→ STEP 2（SwiftUI対応）→ STEP 3（DX整備）→ STEP 4（実機対応）の依存順・工数・完了条件を確定
  - 既存の design.md A/B/C/D 区分との整合確認：STEP 1/2/4 は B/C/D に1対1対応、STEP 3 は新規カテゴリ（対応設計書は追って作成）

### ✅ STEP 1 完了・push 済み（pytest 昇格 / IPC Response schema 確定 / NWConnection 修正）
- **pytest 昇格**: `Tests/conftest.py` / `Tests/test_ipc.py` で run_test.py を pytest として正式化（commit `1e42817` / `b0d978d`）
- **IPC Response schema 確定**: tap / setProperty の Response schema を確定・`docs/ipc-protocol.md` に明文化（commit `1e42817`）
- **NWConnection 部分受信修正**: TCP ソケットの不完全受信対策修正（commit `7f5be89`）
- **GitHub push 完了**: 上記 3 commit が origin/main に統合済み

## 次ステップ：STEP 2（実 SwiftUI コンポーネント計装）
- 目的：STEP 1 で確立した pytest テストランナーを使い、実際の SwiftUI コンポーネント（CLIDemoLoginButton → SwiftUI View）を計装し、エンドツーエンド統合テストの実行可能性を検証する
- ゲート：STEP 1 完了・ブロッカーなし ✅（pytest 環境整備済み、IPC protocol 確定済み）
- 期待結果：SwiftUI コンポーネント 1-2 個の計装完了＋対応する pytest テストの実行・PASS

## 🔄 積み残し
- **MCP ラッパー化（STEP 1.5）**: Dev/ `docs/test-strategy.md` で IPC テスト戦略全体への MCP ラッパー化（Python → Swift 統一化）の差し込み案がレビュー待ち中。STEP 2 着手時点での採否は別途決定（Design C セクションで後追い検討）
