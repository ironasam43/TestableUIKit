# OSS 公開整備ロードマップ

**作成日**: 2026-07-04  
**対象リポジトリ**: `ironasam43/TestableUIKit`（現状: PUBLIC）  
**スコープ**: このドキュメントは「洗い出し・計画」のみ。施策の実施は後続セッション。

> **注**: このドキュメント自体（`docs/oss-publication-roadmap.md`）も内部運用資料であり、P0 の非公開化対象候補に含まれる。

---

## 現状インベントリ（裏取り済み）

### リポジトリ基本情報

| 項目 | 状態 |
|------|------|
| visibility | **PUBLIC** |
| semver タグ | `v0.1.0` / `v0.2.0` の 2 本あり |
| GitHub topics | **未設定**（要設定） |
| CI（ci.yml） | **稼働中**（Swift Package Unit Tests / Build iOS DemoApp / Phase 0 PoC） |

### LICENSE・OSS 標準ファイル

| ファイル | 状態 |
|----------|------|
| LICENSE | **なし** ← **P0 最優先** |
| CONTRIBUTING.md | なし |
| CODE_OF_CONDUCT.md | なし |
| CHANGELOG.md | なし |
| .github/ISSUE_TEMPLATE | なし |
| .github/PULL_REQUEST_TEMPLATE | なし |

### 内部運用ファイル（git 管理下に露出中）

以下は現在 `git ls-files` で追跡されており、PUBLIC リポジトリからそのまま参照可能な状態：

| ファイル/ディレクトリ | 内容 | 対処 |
|----------------------|------|------|
| `CLAUDE.md` | AI エージェント向け設定（内部ツール依存） | `git rm --cached` + gitignore |
| `handoff.md` | セッション間引き継ぎメモ（内部開発状況） | `git rm --cached` + gitignore |
| `docs/blackboard.md` | 設計作業ボード（内部） | `git rm --cached` + gitignore |
| `docs/history.md` | 変更履歴（内部向け詳細ログ） | `git rm --cached` + gitignore |
| `docs/verify-queue.md` | 検証キュー（内部） | `git rm --cached` + gitignore |
| `docs/verify-queue-done.md` | 検証完了ログ（内部） | `git rm --cached` + gitignore |
| `docs/verify-queue.template.md` | VQ テンプレート（内部ツール依存） | `git rm --cached` + gitignore |
| `docs/scenario-authoring-plan.md` | 設計メモ（内部） | `git rm --cached` + gitignore |
| `archive/` | アーカイブ（内部） | `git rm --cached` + gitignore |
| `docs/oss-publication-roadmap.md` | 本ドキュメント（内部計画） | P0 完了後に非公開化（本ドキュメント自体） |

### 言語状態（日本語コンテンツ）

| 対象 | 状態 |
|------|------|
| `README.md` | 日本語（一部英語混在） |
| `SETUP.md` | 日本語 |
| `Example/README.md` | 日本語 |
| `docs/getting-started.md` | 日本語 |
| `docs/troubleshooting.md` | 日本語 |
| `docs/scenario-authoring.md` | 日本語 |
| `docs/ipc-protocol.md` | 日本語 |
| `docs/design.md` | 日本語 |
| `mcp-swift/README.md` | **なし**（未作成） |
| Sources/ 内コメント | 日本語 176 行（30 ファイル中 24 ファイル） |
| mcp-swift/Sources/ 内コメント | 日本語 186 行 |

---

## フェーズ分けロードマップ

### P0: 公開衛生（最優先・施策実施前に Human 判断が必要）

> **前提**: P0 の一部項目（LICENSE 選定・履歴 rewrite 要否）は **Human が決定してから**作業開始すること。

#### P0-1: LICENSE 追加

| 項目 | 詳細 |
|------|------|
| 作業内容 | `LICENSE` ファイルをリポジトリルートに新規作成 |
| 規模感 | 極小（ファイル1本追加） |
| 機械検証 | ○（ファイル存在確認） |
| **⚠️ Human 判断①（必須・着手前）** | **ライセンス種別の選定**: MIT / Apache 2.0 / BSD-2-Clause 等。商用利用・特許条項の有無・コントリビューター扱いを考慮して選択する |

参考:
- **MIT**: 最もシンプル。商用利用可・特許条項なし。OSSライブラリとして最もポピュラー
- **Apache 2.0**: 特許条項あり。企業利用を想定する場合に好まれる
- **BSD-2-Clause**: MIT に近いが出所明示が必要

#### P0-2: 内部ファイルの非追跡化

| 項目 | 詳細 |
|------|------|
| 作業内容 | `git rm --cached <file>` で git 追跡を解除し `.gitignore` に追記。ファイル自体はローカルに残る |
| 規模感 | 小（コマンド数本 + gitignore 追記） |
| 機械検証 | ○（`git ls-files` で追跡解除を確認） |
| Human 判断 | なし（対象ファイルは上記テーブルで確定） |

`.gitignore` への追記案:
```
# 内部運用ファイル（OSS 公開リポジトリでは非追跡）
CLAUDE.md
handoff.md
docs/blackboard.md
docs/history.md
docs/verify-queue.md
docs/verify-queue-done.md
docs/verify-queue.template.md
docs/scenario-authoring-plan.md
docs/oss-publication-roadmap.md
archive/
```

#### P0-3: 履歴 rewrite 要否の判断

| 項目 | 詳細 |
|------|------|
| 作業内容 | `git filter-repo` 等で過去コミットから内部ファイルを除去する場合、force push が必須（破壊的操作） |
| 規模感 | 小〜中（操作自体は自動化可能だが、コントリビューターがいる場合は要調整） |
| 機械検証 | ○（`git log --all -- CLAUDE.md` 等で除去確認） |
| **⚠️ Human 判断②（必須）** | **履歴 rewrite を行うか否か**: `git rm --cached` 以降の HEAD コミットでは内部ファイルは非表示になるが、過去コミットの履歴には残存する。リスク評価と判断: |

判断材料:
- **rewrite しない場合**: `git rm --cached` 後の最新 HEAD では非公開になる。過去コミット（例: `git show <hash>:CLAUDE.md`）からはアクセス可能なまま。リポジトリを見る一般ユーザーには目立たないが、技術的に参照可能
- **rewrite する場合**: `git filter-repo --path CLAUDE.md --invert-paths` 等で過去コミットから完全除去。`git push --force` が必要（スターつきリポジトリやフォーク先への影響に注意）。現在のコントリビューターは作者1名のみ（既存フォーク少数 = 破壊的影響は限定的）
- **推奨**: CLAUDE.md / handoff.md は内部ツール設定であり機密情報（APIキー等）を含まない。rewrite の緊急度は低い。一方で `git rm --cached` は即時対応可能で確実。まず P0-2 を実施し、履歴 rewrite は後日検討としても可

---

### P1: 英語化（Human 判断後に着手）

> **前提**: P1 実施前に方針選択（Human 判断③）が必要。

#### P1-0: 英語化方針の決定

| **⚠️ Human 判断③（必須・P1 着手前）** | **英語化方針の選択** |
|----------------------------------------|----------------------|
| 選択肢A | **英語正本化**: 既存日本語ファイルを英語に全面書き換え。シンプルで管理コスト低。非英語話者の閲覧性は下がる |
| 選択肢B | **バイリンガル（日英並記）**: 日本語・英語を1ファイルに並記（例: 見出し英語・本文に日英両方）。管理コスト高 |
| 選択肢C | **英語正本 + 日本語翻訳版を別ファイル**: `README.md`（英語）+ `README.ja.md`（日本語）のパターン。GitHub の OSS でよく見られる。管理コスト中 |

#### P1-1: 英語化対象ファイル一覧と作業規模

| ファイル | 優先度 | 作業規模 | 備考 |
|----------|--------|---------|------|
| `README.md` | 最高 | 中（全面書き換え or 新規） | リポジトリの顔。P0-2 後の公開状態で最初に読まれる |
| `SETUP.md` | 高 | 中 | 導入手順。英語化価値高 |
| `docs/getting-started.md` | 高 | 中 | 5分計装ガイド |
| `docs/ipc-protocol.md` | 高 | 中 | API 仕様（外部連携者向け） |
| `docs/design.md` | 中 | 大（長文） | アーキテクチャ設計書。コントリビューター向け |
| `docs/troubleshooting.md` | 中 | 小〜中 | |
| `docs/scenario-authoring.md` | 中 | 小〜中 | MCP シナリオ向け（AI 利用者向け） |
| `Example/README.md` | 中 | 小 | |
| Sources/ コメント（176行） | 低 | 中 | ロジック変更なし・コメントのみ |
| mcp-swift/Sources/ コメント（186行） | 低 | 中 | 同上 |

> 内部ファイル（blackboard / history 等）は P0-2 で非追跡化される前提のため翻訳不要。

---

### P2: OSS 標準整備

> P1 と並行または P1 後に実施可能。Human 判断④（著者名義）のみ事前確認が必要。

#### P2-1: CONTRIBUTING.md

| 項目 | 詳細 |
|------|------|
| 作業内容 | コントリビューション手順（Issue → Fork → PR のフロー・コーディング規約・テスト実行手順）を記述 |
| 規模感 | 小（テンプレートベースで作成可） |
| 機械検証 | ○（ファイル存在確認） |
| Human 判断 | なし（内容は GitHub 標準 OSS 慣行に準拠） |

#### P2-2: CODE_OF_CONDUCT.md

| 項目 | 詳細 |
|------|------|
| 作業内容 | Contributor Covenant（標準行動規範）の採用 |
| 規模感 | 極小（定型文の採用） |
| 機械検証 | ○（ファイル存在確認） |
| **⚠️ Human 判断④（必須）** | **著者名義表記**: CODE_OF_CONDUCT に連絡先メールアドレスを記載する必要がある（違反報告の宛先として）。公開する連絡先を決定すること |

#### P2-3: CHANGELOG.md

| 項目 | 詳細 |
|------|------|
| 作業内容 | `v0.1.0` / `v0.2.0` の変更内容を [Keep a Changelog](https://keepachangelog.com/) 形式で記述 |
| 規模感 | 小（既存 `docs/history.md` から要点を抽出して英語化） |
| 機械検証 | ○（ファイル存在確認） |
| Human 判断 | なし |

#### P2-4: .github/ISSUE_TEMPLATE

| 項目 | 詳細 |
|------|------|
| 作業内容 | Bug Report / Feature Request の2テンプレートを作成（`.github/ISSUE_TEMPLATE/`） |
| 規模感 | 小 |
| 機械検証 | ○（ファイル存在確認） |
| Human 判断 | なし |

#### P2-5: .github/PULL_REQUEST_TEMPLATE.md

| 項目 | 詳細 |
|------|------|
| 作業内容 | PR チェックリスト（テスト実行・ドキュメント更新等）を含むテンプレート |
| 規模感 | 極小 |
| 機械検証 | ○ |
| Human 判断 | なし |

#### P2-6: mcp-swift/README.md 新規作成

| 項目 | 詳細 |
|------|------|
| 作業内容 | `mcp-swift/` サブパッケージの README（Swift MCP サーバの概要・ビルド・起動方法・ツール一覧） |
| 規模感 | 小 |
| 機械検証 | ○ |
| Human 判断 | なし |

---

### P3: 訴求（P0〜P2 完了後）

#### P3-1: GitHub topics 設定

| 項目 | 詳細 |
|------|------|
| 作業内容 | `gh repo edit --add-topic` で topics を設定（候補: `swift` / `ios` / `swiftui` / `testing` / `ui-testing` / `mcp` / `llm` / `ai-agent`） |
| 規模感 | 極小 |
| 機械検証 | ○（`gh repo view --json repositoryTopics`） |
| Human 判断 | なし（候補から選択） |

#### P3-2: バッジ追加（README.md）

| 項目 | 詳細 |
|------|------|
| 作業内容 | CI バッジ・Swift バージョンバッジ・LICENSE バッジを README 冒頭に追加 |
| 規模感 | 極小 |
| 機械検証 | △（URL の有効性確認は可。表示は要実機確認） |
| Human 判断 | なし（P0-1 の LICENSE 選定完了後に実施） |

#### P3-3: semver 運用ルール明文化

| 項目 | 詳細 |
|------|------|
| 現状 | `v0.1.0` / `v0.2.0` の 2 タグが存在。次タグのルールは未文書化 |
| 作業内容 | CONTRIBUTING.md または CHANGELOG.md にリリース手順（タグ命名規則・リリースノート）を明記 |
| 規模感 | 極小（数行追記） |
| 機械検証 | ○ |
| Human 判断 | なし |

#### P3-4: デモ GIF 追加（README.md）

| 項目 | 詳細 |
|------|------|
| 作業内容 | MCP ツールを AI エージェントが駆動するシーンを録画・GIF 化して README トップに追加 |
| 規模感 | 中（録画・編集・アップロード） |
| 機械検証 | △（ファイル存在確認のみ。視覚的品質は人間確認） |
| Human 判断 | なし（任意） |

---

## Human 判断まとめ（着手前に確認が必要な4点）

| # | フェーズ | 判断事項 | 選択肢 |
|---|---------|---------|--------|
| ① | P0-1 | **LICENSE 種別の選定** | MIT / Apache 2.0 / BSD-2-Clause / その他 |
| ② | P0-3 | **過去コミット履歴の rewrite を行うか** | する（filter-repo + force push）/ しない（HEAD のみ非追跡化で許容） |
| ③ | P1-0 | **英語化方針の選択** | A: 英語正本化 / B: バイリンガル並記 / C: 英語正本 + `README.ja.md` 等の分離 |
| ④ | P2-2 | **著者名義・連絡先メールアドレス（CODE_OF_CONDUCT 記載用）** | 公開する連絡先を決定 |

---

## 実施順のおすすめ

```
P0（公開衛生）
 ├─ Human 判断①②を確認
 ├─ P0-1: LICENSE 追加
 ├─ P0-2: git rm --cached + gitignore（内部ファイル非追跡化）
 └─ P0-3: 履歴 rewrite（Human 判断②に従い実施 or スキップ）

P1（英語化）
 ├─ Human 判断③を確認
 └─ README.md → SETUP.md → docs/ → ソースコメントの順で英語化

P2（OSS 標準整備）                       ← P1 と並行可
 ├─ Human 判断④を確認
 ├─ CONTRIBUTING.md / CODE_OF_CONDUCT.md / CHANGELOG.md
 ├─ .github/ テンプレート
 └─ mcp-swift/README.md

P3（訴求）                               ← P0〜P2 完了後
 ├─ GitHub topics
 ├─ バッジ
 ├─ semver ルール明文化
 └─ デモ GIF（任意）
```

---

*本ドキュメントは内部計画用。P0-2 完了後に `.gitignore` に追記し非追跡化すること。*
