# TestableUIKit 実用化ロードマップ

**最終更新**: 2026-06-23  
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

> **進捗注記（2026-06-23）**: 推奨ルートの想定（STEP1→2→3→4）に対し、実際は **STEP 2 が超過達成・STEP 4 が完走**し、**STEP 3（配布・DX）が部分残り**という逆転が起きている。詳細は各 STEP の見出しを参照。

**コア実装**:
- `AnyTestable` protocol（testID / describedState / perform）✅
- `TestableServer`（HTTP over localhost:8888・実機向け `0.0.0.0` 公開 ＋ `GET /screenshot` 対応）✅
- `TestableRegistry` ✅ — **シングルトン廃止・SwiftUI Environment キー注入方式へ移行済み**（STEP 4 関連リファクタ）
- 統一コマンド I/F（`getState` / `tap` / `setProperty` / `setEnabled`）✅
- 5キー固定 describedState（isEnabled / title / isHidden / alpha / backgroundColor）✅

**実装例 / 計装**:
- iOS DemoApp（UIKit LoginButton）✅
- CLI executable（TestableUIKitDemo）✅
- Core logic の DRY 抽出（LoginButtonCore）✅
- **`.testable(_:)` ViewModifier 実装済み**（`Sources/TestableUIKit/TestableView.swift`）✅
- **多様コンポーネント計装**：`CounterCore` / `TextInputCore` / `OnOffSwitchCore` / `RangeSliderCore` の 4 Core 実装済み ✅

**MCP 連携**:
- **独立 MCP サーバ（`mcp_server/testableui_mcp.py`）実装済み**：`ui_ping` / `ui_getState` / `ui_perform` / `ui_screenshot` の 4 ツール ✅

**品質**:
- CI 全3ジョブ ✅ PASS：
  - Swift Package Unit Tests
  - Build iOS DemoApp
  - Phase 0 PoC - Simulator Boot, App Launch & Loopback
- **テスト規模：`swift test` 100 PASS / `pytest` 59 PASS** ✅（PoC 当初の 23 PASS から大幅進展）

**ドキュメント**:
- `docs/design.md`（アーキテクチャ・定義A/B・テスト哲学・§D 実機対応）✅
- `docs/ipc-protocol.md`（HTTP API 仕様・`GET /screenshot` 追記）✅

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

### STEP 2: SwiftUI コンポーネント対応 ✅ 完了（超過達成）

**内容**: CLI スタブ実装（CLIDemoLoginButton）から実 SwiftUI コンポーネント（Button / Toggle / TextField など）へ移行。ViewModifier + Registry で任意の View を Testable 化

**実績（2026-06-23）**: 
- ✅ `.testable(_:)` ViewModifier 実装済み（`Sources/TestableUIKit/TestableView.swift`）。任意の SwiftUI View を Testable に透過的にラップ
- ✅ TestableRegistry アクセスは Environment キー注入方式で実現（STEP 4 で EnvironmentObject から移行・超過達成）
- ✅ 多様コンポーネント計装：`CounterCore` / `TextInputCore` / `OnOffSwitchCore` / `RangeSliderCore` の 4 Core を実装（当初目標「3 以上」を超過）
- ✅ Counter / TextInput / OnOffSwitch / RangeSlider で計装テスト実証（`swift test` 100 PASS の一部）

**完了条件**（すべて達成）:
1. ✅ ViewModifier `.testable(_:)` を実装。任意の SwiftUI View を Testable に透過的にラップ
2. ✅ Registry アクセスを Environment キー注入で実現（EnvironmentObject 案を上回るシングルトンレス設計へ）
3. ✅ DemoApp のコンポーネント数を 3 以上に増加（4 Core）
4. ✅ 各種 View（Counter / TextInput / OnOffSwitch / RangeSlider）で計装テスト実証

**対応設計書**: [Design C](design.md#c-swiftui-コンポーネント対応) — SwiftUI コンポーネント対応

---

### STEP 3: 配布・DX 整備 🟡 部分残り（全PJ展開の律速）

**内容**: オープンソース化・採用支援の基盤整備。SPM semver タグ付与、README getting-started、自作コンポーネント計装手順、最小サンプル、堅牢化（ポート競合・多重起動・エラー応答）

**現状（2026-06-23）**: 
- コア機能・実機対応は完成・CI green。SETUP.md / README に実機ペアリング・screenshot 経路の運用手順は明文化済み
- ただし**外部利用者向けの配布パッケージング一式が未整備** → 本 STEP が **TestableUIKit の全PJ展開の律速**（`Dev/docs/test-strategy.md` §7 課題 B と整合）
- ポート 8888 競合時の動作が未定義（graceful shutdown 未実装）
- Bundle ID が placeholder 値

**完了条件**（残タスク）:
1. ⬜ `docs/getting-started.md`：5分で自分のコンポーネントを計装可能な step-by-step ガイド
2. 🟡 `docs/troubleshooting.md`：ポート競合・多重起動・タイムアウト時の対応（SETUP.md に一部記載あり・独立化は未）
3. ⬜ GitHub Releases で semver タグ（v0.1.0 以降）を打付
4. ⬜ README に getting-started へのリンク追加
5. ⬜ Bundle ID を正式値に確定（社内 or community namespace）
6. ⬜ TestableServer に graceful shutdown・エラーレスポンス改善
7. ⬜ `Example/` ディレクトリに「自分のコンポーネントをテストする」サンプル

**工数**: 小〜中（0.5〜1.5 セッション）

**対応設計書**: 新規カテゴリ（対応設計書は STEP 3 開始時に作成予定）

---

### STEP 4: 実機対応 ✅ 完了（推奨ルートに反し先行完走）

**内容**: iOS Simulator から実 iPhone デバイスでのテスト実行に拡張。Provisioning Profile・Device UUID 管理・Wi-Fi 経由 IPC（localhost:8888 → Wi-Fi endpoint）

**実績（2026-06-23）**: 
- ✅ 実機 iPhone `192.168.0.181` で Wi-Fi 越し IPC 疎通成立。`DemoApp` を `#if DEBUG` 分岐で `host: "0.0.0.0"` 公開
- ✅ MCP 4 ツール（`ui_ping` / `ui_getState` / `ui_perform` / `ui_screenshot`）が **4/4 実機 e2e でクローズ**
- ✅ `ui_screenshot` は経路A（`GET /screenshot` アプリ内キャプチャ）で Simulator 非依存に実機 PNG 取得確認（79,768 bytes・960×1440・PNG シグネチャ一致）
- ✅ `TESTABLE_IPC_HOST` による接続先切替・実機ペアリング手順を SETUP.md / README に明文化

**完了条件**（達成状況）:
1. ✅ Provisioning Profile / 実機ペアリング手順を SETUP.md に文書化
2. ✅ `TestableServer` を `0.0.0.0` で listen（デバイスの IP:port で疎通）
3. 🟡 接続先は `TESTABLE_IPC_HOST` で手動指定（DHCP 変動時の手順を明文化。UUID 自動検出は未実装だが運用でカバー）
4. ⬜ GitHub Actions への実機接続統合は未（ローカル実機 e2e で実証・CI 自動化は範囲外）
5. ✅ ローカルで実 iPhone でのテスト実行（4/4 ツール駆動）を確認

**注記（推奨ルートとの逆転）**: 当初は「STEP 4 後回し可」としていたが、実際は **STEP 4 を先行完走**し、STEP 3（配布・DX）が部分残りという順序逆転が起きた。実機 e2e の早期成立により価値実証は前倒しできた一方、外部公開に必要な STEP 3 が律速として残る形になった。

**対応設計書**: [Design D](design.md#d-実機テスト対応) — 実機テスト対応

---

## 4. 推奨ルート（当初計画）と実際の進行

> **実際の進行（2026-06-23）**: STEP 1 ✅ → STEP 2 ✅（超過達成）→ **STEP 4 ✅（先行完走）** → STEP 3 🟡（部分残り・律速）。下記は当初計画。実際は実機対応（STEP 4）を価値実証のため前倒しで完走し、配布・DX（STEP 3）が外部公開の律速として残った。

```
STEP 1（テストランナー昇格）✅
    ↓ [土台完成]
STEP 2（SwiftUI コンポーネント）✅ 超過達成
    ↓ [本丸完成 = 他人が組み込める]
    └─ 並行（一部）→ 堅牢化・簡易 STEP 3
    ↓
STEP 3（配布・DX 整備）🟡 部分残り ← 現在の律速
    ↓ [公開準備完成 = 誰でも使える]
STEP 4（実機対応）✅ 先行完走（当初は「後回し可」）
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
