# シナリオ・オーサリング支援（AI がシナリオを書けるようにする仕組み）設計メモ

最終更新：2026-07-04
ステータス：**方針把握のみ・未着手**（ユーザー選択＝「4. いまは方針把握だけ／セッションを切る」）

## 背景・問題

`ui_runScenario`（宣言的シナリオ実行）は実装済み（commit `37e835d`）。だが「シナリオの書き方」を
機械／人間に伝える情報が薄く、MCP 接続した AI が勘で書くしかない状態。

### いまの「書き方」情報の在りか（実態）

| 場所 | 中身 | AI がシナリオを書く助けになるか |
|---|---|---|
| MCP `ui_runScenario` inputSchema | `{ name, steps:[{action, testID, parameters?, expect?}] }` の一行説明のみ | ❌ 骨格だけ。action 一覧も expect キーも無い |
| `docs/design.md` §E2 | アーキテクチャ視点の記述 | △ 設計者向け・書式カタログでない |
| `docs/ipc-protocol.md` | 1 箇所言及のみ | △ |
| `Example/scenarios/*.json` | 動くサンプル2本（counter-flow / login-flow） | ○ 例からの類推は可 |
| 専用の書式仕様 / JSON Schema / テンプレート | **なし** | ❌ |

要点：MCP 経由の AI が実際に読むのは **tool の inputSchema**。そこに
「`action` に何が使えるか（getState/tap/setProperty/setEnabled/increment…）」
「`expect` に何を書けるか（固定5キー isEnabled/title/isHidden/alpha/backgroundColor ＋ count 等コンポーネント固有キー）」
「action ごとの `parameters` 形（setProperty は key/value 必須）」が一切ない。

## 打ち手（MCP 主役なら上から優先）

1. **MCP tool schema の拡充（最優先・最も MCP らしい）**
   - `action` を enum 化、`expect` キー・`parameters` 形を inputSchema 内に明記。
   - 接続時にあらゆる AI クライアントが自動で読む → 「ドキュメントを渡す」不要・自己記述的。
2. **JSON Schema ファイル**（`Example/scenarios/scenario.schema.json`）
   - サンプルに `$schema` 参照を付与 → エディタ補完＋実行前バリデーション。AI に食わせる素材にもなる。
3. **オーサリング doc**（`docs/scenario-authoring.md` か ipc-protocol.md に節追加）
   - 人＋AI 両用の書式仕様：action カタログ・expect キーカタログ・注釈付き完全例・
     落とし穴（例：無効化後は increment しても count 据え置き＝操作ガード）。README からリンク。

→ 1＋2 は「機械が読む」ので “AI が書けるようにする” に直撃。3 は人間向け公開ドキュメント。3点で一貫パッケージ。

## スコープ選択肢（次セッションで決定）

- **案A フルセット**：tool schema 拡充 ＋ JSON Schema ＋ オーサリング doc ＋ README リンク（AI 自動読み取り＋人間公開の両輪・cmflow で設計から）
- **案B MCP 機械可読分のみ**：tool schema 拡充 ＋ JSON Schema（AI が書ける状態を最短で・doc 後回し）
- **案C doc だけ**：`docs/scenario-authoring.md` ＋ README 節（実装/schema は触らず書式を文章化）

推奨：MCP を主役に据えるなら **案A**（または段階的に B → A）。

## 設計上の含意（CM 確認事項・要注意）

- `action` を schema の enum に固定すると「対応コマンドの正本」が schema 側に生まれ、
  **コマンド追加時の同期対象が増える**（軽微だが `docs/design.md` に注記が要る）。
- expect の固定5キー（isEnabled/title/isHidden/alpha/backgroundColor）と
  コンポーネント固有キー（count 等）の扱いを schema でどう表現するか要検討
  （固定キーは enum/型付け、固有キーは additionalProperties 許容など）。
- Phase2 で `docs/design.md`（§E2）・`docs/ipc-protocol.md` との整合を CM 確認して固める前提。

## 再開手順

1. 本メモを読む → スコープ案A/B/C を Human に確認（[ASK HUMAN]）。
2. 決定後、cmflow Phase1（`ui_runScenario` の inputSchema と Scenario.swift の action 対応を実態確認）
   → Phase2 方針立案＋CM 確認 → Phase3 実装。
3. 関連実装：`mcp-swift/Sources/TestableUIKitMCP/main.swift`（tool 登録・inputSchema）、
   `mcp-swift/Sources/TestableUIKitMCPCore/Scenario.swift`（モデル・evaluateExpect）、
   `Example/scenarios/`（サンプル・schema 置き場候補）。
