# TestableUIKit 実用化ロードマップ

**最終更新**: 2026-06-02  
**対象**: TestableUIKit プロジェクト全体

---

## 1. 実用化の定義

**実用化**＝「他人が自分のアプリの UI コンポーネントに組み込んで UI テストを書ける状態」

現在の段階（Phase 0 PoC）では「自作デモを自分でテストできる」ところまで到達。実用化には以下が必要：

- テストランナーの正式スイート化（tap/setProperty の Response schema 確定）
- 実 SwiftUI コンポーネント対応
- 配布・導入の DX 整備（semver タグ、README、計装手順、サンプル）
- 堅牢性の向上（ポート競合、多重起動、エラー応答）

---

## 2. 現在地（到達済み）

**コア実装**:
- `AnyTestable` protocol（testID / describedState / perform）✅
- `TestableServer`（HTTP over localhost:8888）✅
- `TestableRegistry`（Component 中央管理）✅
- 統一コマンド I/F（`getState` / `tap` / `setProperty` / `setEnabled`）✅
- 5キー固定 describedState（isEnabled / title / isHidden / alpha / backgroundColor）✅

**実装例**:
- iOS DemoApp（UIKit LoginButton）✅
- CLI executable（TestableUIKitDemo）✅
- Core logic の DRY 抽出（LoginButtonCore）✅

**品質**:
- CI 全3ジョブ ✅ PASS：
  - Swift Package Unit Tests
  - Build iOS DemoApp
  - Phase 0 PoC - Simulator Boot, App Launch & Loopback
- テスト 23 PASS ✅

**ドキュメント**:
- `docs/design.md`（アーキテクチャ・定義A/B・テスト哲学）✅
- `docs/ipc-protocol.md`（HTTP API 仕様）✅

---

## 3. 実用化への4ステップ

### STEP 1: テストランナー昇格

**内容**: `run_test.py` を正式な pytest テストスイートに統合し、tap・setProperty の Response schema を確定

**現状**: 
- run_test.py は integration テスト（Phase A/B/B-5）
- getState のみ assert 済み
- tap・setProperty の Response schema は未確定（run_test.py 全行照合で仕様確認中）

**完了条件**:
1. tap・setProperty の Response schema を `docs/ipc-protocol.md` で本格確定
2. run_test.py を pytest フレームワークに再実装（fixtures / parametrize 等）
3. CI ワークフロー内で `pytest` ジョブを統合実行
4. テスト 23+ PASS（既存の swift test との並行）

**工数**: 小（0.5〜1 セッション）

**対応設計書**: [Design B](design.md#b-テストランナー統合) — テストランナー統合

---

### STEP 2: SwiftUI コンポーネント対応

**内容**: CLI スタブ実装（CLIDemoLoginButton）から実 SwiftUI コンポーネント（Button / Toggle / TextField など）へ移行。ViewModifier + Registry で任意の View を Testable 化

**現状**: 
- iOS DemoApp の LoginButton は AnyTestable を直接実装した @MainActor class
- 実際の SwiftUI primitive（Button / Toggle 等）は Testable に非対応

**完了条件**:
1. ViewModifier `@testable(_:)` を実装。任意の SwiftUI View を Testable に透過的にラップ
2. EnvironmentObject で TestableRegistry アクセス可能に
3. DemoApp のコンポーネント数を 3 以上に増加
4. 各種 View（Button / Toggle / TextField / Picker）で計装テスト実証

**工数**: 中〜大（1〜2 セッション / 設計変更）

**対応設計書**: [Design C](design.md#c-swiftui-コンポーネント対応) — SwiftUI コンポーネント対応

---

### STEP 3: 配布・DX 整備

**内容**: オープンソース化・採用支援の基盤整備。SPM semver タグ付与、README getting-started、自作コンポーネント計装手順、最小サンプル、堅牢化（ポート競合・多重起動・エラー応答）

**現状**: 
- コア機能は完成・CI green だが、外部利用者向けドキュメント・配布パッケージング一式が未整備
- ポート 8888 競合時の動作が未定義
- Bundle ID が placeholder 値

**完了条件**:
1. `docs/getting-started.md`：5分で自分のコンポーネントを計装可能な step-by-step ガイド
2. `docs/troubleshooting.md`：ポート競合・多重起動・タイムアウト時の対応
3. GitHub Releases で semver タグ（v0.1.0 以降）を打付
4. README に getting-started へのリンク追加
5. Bundle ID を正式値に確定（社内 or community namespace）
6. TestableServer に graceful shutdown・エラーレスポンス改善
7. Example/ ディレクトリに「自分のコンポーネントをテストする」サンプル

**工数**: 小〜中（0.5〜1.5 セッション）

**対応設計書**: 新規カテゴリ（対応設計書は STEP 3 開始時に作成予定）

---

### STEP 4: 実機対応

**内容**: iOS Simulator から実 iPhone デバイスでのテスト実行に拡張。Provisioning Profile・Device UUID 管理・Wi-Fi 経由 IPC（localhost:8888 → Wi-Fi endpoint）

**現状**: 
- Simulator のみ対応
- localhost:8888 固定（実機では接続不可）

**完了条件**:
1. Provisioning Profile セットアップガイド文書化
2. `TestableServer` に Wi-Fi endpoint 対応（デバイスの IP:port で listen）
3. Device UUID を自動検出・登録する仕組み
4. GitHub Actions に実機接続設定（local runner or App Store Connect key 等）
5. CI で実 iPhone でのテスト実行を確認

**工数**: 大（1〜2 セッション / インフラ・デバイス管理）

**後回し理由**: Simulator で STEP 1-3 が完成すれば既に「他人が組み込んでテストできる」状態。実機は nice-to-have。

**対応設計書**: [Design D](design.md#d-実機テスト対応) — 実機テスト対応

---

## 4. 推奨ルート

```
STEP 1（テストランナー昇格）
    ↓ [土台完成]
STEP 2（SwiftUI コンポーネント）← 実装フェーズ
    ↓ [本丸完成 = 他人が組み込める]
    └─ 並行（一部）→ 堅牢化・簡易 STEP 3
    ↓
STEP 3（配布・DX 整備）
    ↓ [公開準備完成 = 誰でも使える]
STEP 4（実機対応）← 後回し可
```

**論理的根拠（手戻り最小）**:

1. **STEP 1 最優先（土台）**: tap/setProperty schema が未確定だと STEP 2 コンポーネント計装時に仕様揺れのリスク。先に確定し安定した IPC I/F を確保
2. **STEP 2（本丸）**: CLIDemoLoginButton PoC から実 SwiftUI に移行。この時点で「自分のコンポーネントに組み込める」達成
3. **STEP 3（配布）**: STEP 2 で本丸完成後、ドキュメント・例・bundle ID 等の周辺整備。既に使える状態で DX polish
4. **STEP 4（実機）**: Simulator で全機能動作確認後の拡張。Simulator で十分なら不要。後回し推奨

この順序なら：
- STEP 1-2 で「実用化」達成（他人が組み込める）
- STEP 3 で「誰でも使える」
- STEP 4 は「より使いやすく」（オプション）

逆順（STEP 4 先行等）だと、実機環境構築にコスト大のまま、ユースケースが明確でない段階で投資することになり inefficient。

---

## 参考資料

- `docs/design.md` — M-4 テーマ候補 A/B/C/D の詳細仕様
- `docs/history.md` — マイルストーン M-1〜M-5 の進捗サマリー
- `docs/ipc-protocol.md` — HTTP API 仕様（STEP 1 で拡張予定）
- `handoff.md` — プロジェクト作業メモ
