# 変更履歴

> 新規作成（2026-06-02）。これまでの作業は handoff_1.md より要約。

## サマリー

- **M-1 IPC層検証** ✅: JSONValue（single value container）/ AnyTestable / TestableServer（NWListener, strict-concurrency PASS）/ CLI executable 実装。`swift build` / `swift test`(6) / `run_test.py` で wire format 実証。
- **M-2 iOS App UI連動** ✅: pbxproj 重複 isa 修復、LoginButton 実装、Simulator 上で getState→tap→getState の状態変化（isEnabled true→false）実証。ipc-protocol.md / design.md 整備。
- **M-3a xcodegen 移行** ✅: project.yml 宣言的管理へ移行、pbxproj 手編集廃止。
- **M-3-0 git cleanup** ✅: `.build/` `DerivedData/` は git 非追跡を確認。
- **M-3-1 OS/device matrix 確定** ✅: iOS 16.0 / device matrix = iPhone 16 + iPad Air（Human 確定）。
- **M-3-3 CI/CD 統合** ✅: GitHub Actions workflow 作成・green PASS。
- **M-4 setProperty 拡張** ✅: isEnabled/title に加え isHidden/alpha/backgroundColor 追加。合計 23 tests PASS。
- **M-5 テストランナー統合（進行中）**: Phase 0 PoC（probe-simulator job）修正完了（commit 5de08ca + 0f23586：iPhone UDID 選択 / bootstatus オプション修正）。CI push → **全3ジョブ ✅ PASS**（Swift Package Unit Tests / Build iOS DemoApp / Phase 0 PoC Simulator Boot App Launch & Loopback）。実 API 仕様を run_test.py 全行照合で確定（GET /ping, POST /perform で discriminate）。Phase 1 着手待機中。
- **M-5+ 実用化ロードマップ確定** ✅: `docs/roadmap.md` を新規作成。実用化の定義・現在地（到達済み）・STEP 1-4（テストランナー昇格→SwiftUI対応→DX整備→実機対応）・推奨ルート（手戻り最小）を明文化。STEP 1/2/4 は既存設計書 B/C/D に1対1対応、STEP 3 は新規カテゴリ。
