最終更新：2026-06-02

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

## 現在地：M-5（テストランナー統合）進行中 → 実用化ロードマップ確定 ✅

### ✅ 完了済み
- Phase 0 PoC `probe-simulator` job 修正完了（commit `5de08ca` + `0f23586`）
  - commit `5de08ca`：`--terminate-running-process` フラグ追加、process check を `launchctl list | grep com.testable.TestableUIKitDemo` に修正
  - commit `0f23586`：iPhone UDID での正確なデバイス選択（.name → .udid、startswith("iPhone") フィルタ）、bootstatus コマンドから非存在オプション `--timeout 300` を削除
  - **CI 全3ジョブ ✅ PASS**: Swift Package Unit Tests / Build iOS DemoApp / Phase 0 PoC - Simulator Boot, App Launch & Loopback
- 実 API 仕様を `run_test.py` 全行照合で確定：
  - `GET /ping` → `{"status":"ok"}`
  - `POST /perform` body: `{"testID","commandName":"getState"|"tap"|"setProperty","parameters":{}|{"key","value"}}`
  - ⚠️ 単独エンドポイント（/setProperty 等）は存在しない。すべて `POST /perform` で discriminate
  - ⚠️ tap/setProperty の Response schema は未 assert（Phase 1 設計時に確定）。getState のみ確定済み
- **実用化ロードマップを正式ドキュメント化** ✅
  - `docs/roadmap.md` 新規作成：実用化の定義、現在地（到達済み）、4ステップ（STEP 1-4）、推奨ルートを明文化
  - STEP 1（テストランナー昇格）→ STEP 2（SwiftUI対応）→ STEP 3（DX整備）→ STEP 4（実機対応）の依存順・工数・完了条件を確定
  - 既存の design.md A/B/C/D 区分との整合確認：STEP 1/2/4 は B/C/D に1対1対応、STEP 3 は新規カテゴリ（対応設計書は追って作成）

### 🔄 次セッション開始前の必須手順（Phase 1 着手）
1. GitHub PAT に `workflow` scope 追加（Human 対応）
2. `git push --dry-run` で scope 検証 → `git log origin/main..HEAD | wc -l` で commit 数再取得
3. scope OK 後 `git push` → GitHub Actions 自動開始
4. CI 結果：PASS→Phase 0 job 削除＋Phase 1 着手 / FAIL（同一カテゴリ×2回）→案B（XCTest UITest）へ撤退

### Phase 1 開始条件
- Phase 0 CI PASS 必須（GitHub PAT scope 後）
- `docs/roadmap.md` で実用化パス確定 ✅ → Phase 1 = roadmap.md STEP 1（テストランナー昇格）着手
- run_test.py 全行照合に基づく pytest 重設計
- tap・setProperty Response schema 本格確定

## M-5+ 候補
- M-5: run_test.py を pytest/XCTest 正式スイート昇格・CI 組込（xcodebuild test）
- M-5: 実機テスト対応（Provisioning・device UUID 管理／高コスト）
- M-6: SwiftUI コンポーネント対応（CLIDemoLoginButton → SwiftUI View）
- 低優先：setProperty 拡張（fontSize/textColor/cornerRadius）、マルチコンポーネント統合テスト、CI matrix 複数 iOS 版
