# [照会] B（MCP サーバ）の Swift 化・SPM 公開の実現可否・工数

- 発生元: HQ（Dev/ タブ）対話セッション 2026-06-24
- 種別: 照会（実装依頼ではなく、可否・工数の見積り回答を求める）
- 消化モード: フロー（Phase1 分析→回答。実装着手は別途合意後）
- 検収: 必要（回答を HQ が受領して §6 #3 を最終確定するため）

## 背景

HQ 側で TestableUIKit 全PJ展開戦略（`Dev/docs/test-strategy.md` §6 #3 / §7）を詰めている。
ユーザ提示の目標構成は次の3点で、ProjectDeck からは GitHub SPM 参照で取り込む想定：

- **A. demo アプリ**
- **B. builtin MCP サーバ（SPM 公開）**
- **C. TestableUIKit ライブラリ（SPM 公開）**

実コードを読んだ HQ の認識：

- 知能（state モデル・perform・HTTP サーバ）は全て **C（Swift）** に閉じている。
- 現状の **B＝`mcp_server/testableui_mcp.py` は Python（約293行）・状態レスな HTTP↔MCP 中継**で固有ロジックを持たない。
- 層の境界は MCP ではなく **HTTP（:8888）**。

→ HQ の方向性（`test-strategy.md` §6 #3 に方向性確定として記載済み）は
**「B を Python から Swift MCP サーバへ書き直し、C と同一 SPM パッケージで公開する」**。
これにより SPM 公開可・利用者の venv/別プロセス起動が消える・ProjectDeck が SPM 依存で link できる、という見立て。

## 確認したいこと（回答してほしい項目）

1. **MCP Swift SDK の採用可否**: `modelcontextprotocol/swift-sdk`（または相当）で
   現状4ツール（`ui_ping` / `getState` / `perform` / `screenshot`）を Swift で再実装できるか。
   stdio トランスポート・FastMCP 相当の DX が Swift 側で成立するか。
2. **Package.swift への MCP server target 追加の工数感**（executable product 化・依存追加・ビルド構成）。S/M/L で可。
3. **screenshot の simctl 依存の扱い**: 現状 `simctl io booted` fallback を Swift 側へ移植する際の
   実機/LAN provider 注入経路との整合（既存 `/screenshot` provider で吸収できるか）。
4. **Python 版 B の去就**: Swift 化後、Python 版を CI/外部用に残すか・廃止するかの当事者見解。
5. **SPM 公開の前提整備**: C の semver git タグ（現状皆無で version pin 不可）・public API 監査の要否と工数。

## 完了条件

上記1〜5に対する当事者（TestableUIKit）見解を返すこと。実装着手は不要（可否・工数の回答のみ）。
回答受領後、HQ が `Dev/docs/test-strategy.md` §6 #3 を最終確定する。

## 参考

- 正本: `Dev/docs/test-strategy.md` §6 #3（方向性確定）・§7（全PJ展開分析）
- 前回連携: `2026-06-23-roadmap-drift-update.md`（消化済み `710a6ad`）

---

## 回答（当事者＝TestableUIKit 見解 / 2026-06-24・一次情報裏取り済み）

> 前提整理（§6 #3 の精度向上のため）: 層境界は HTTP(:8888)。B は Python/Swift いずれでも
> **Mac ホスト上で動く stdio MCP ↔ HTTP ブリッジの別プロセス**であり、iOS app には link されない。
> Swift 化の便益は「in-process 化」ではなく **①venv 消滅 ②SPM 配布可 ③単一言語**。
> ProjectDeck は SPM パッケージを取り込み executable をビルド＆stdio subprocess として spawn する形になる
> （ProjectDeck 本体バイナリへの static link ではない）。この点を §6 #3 の表現に反映推奨。

### 1. MCP Swift SDK 採用可否 → **可（実現可能）**
- `modelcontextprotocol/swift-sdk`（公式）は stdio transport を正式サポート。現状4ツールは
  いずれも薄い HTTP 中継（`ipc_helpers.py` の純関数＋requests）で固有ロジックを持たないため、
  URLSession(async) へ置換すれば等価に Swift 再実装できる。技術的障壁なし。
- ただし **FastMCP 相当の DX は完全には得られない**: Python の `@mcp.tool()`＋docstring 自動推論に対し、
  Swift SDK は Tool 定義（name / description / inputSchema=JSON Schema）と handler closure を
  手動登録する方式。記述量は増えるが、4ツールの schema は単純（testID:String, command:String, params:obj?）
  なので実装負荷は小さい。

### 2. Package.swift への target 追加工数 → **S〜M**
- `.executableTarget`（例 `TestableUIKitMCP`）＋ `.executable` product を追加、
  `dependencies` に swift-sdk を1本追加。ライブラリ本体への依存は必須ではない（純 HTTP client）が、
  wire 型（PerformRequest/JSONValue）共有で型安全化するなら lib 依存を付けてもよい。
- 工数: ロジック自体は ~178行 Python 相当で軽い。主作業は swift-sdk Server API 習得＋JSON Schema 記述＋
  URLSession 化＋エラーマッピング＋L1 テスト整備。**目安 S（半日）〜M（1〜1.5日）**。
- ⚠️ **トレードオフ要注意**: 現状 Package.swift は外部依存ゼロ（CLAUDE.md で「外部依存なし」を差別化に明記）。
  swift-sdk 導入は library 本体ではなく MCP executable target 限定に閉じれば、
  C（library）の「依存ゼロ」は維持できる。依存の波及範囲を target 分離で封じ込めるのが条件。

### 3. screenshot の simctl 依存 → **既存 provider 経路で吸収可・整合する**
- 現状アーキで screenshot 一次経路は既に `GET /screenshot`（app 側 `screenshotProvider` 注入による
  アプリ内キャプチャ）に移行済みで、**実機・Simulator 共通・host 非依存**。Swift MCP からは
  この GET を叩くだけで完結し simctl 不要。実機/LAN provider 注入経路と完全整合（直交関係）。
- simctl fallback（`xcrun simctl io booted screenshot`）は loopback かつ /screenshot 不達時のみ。
  Swift 移植時は `Foundation.Process` で xcrun を呼べば等価（MCP server は Mac ホストで動くため Process 可）。
  → **fallback は「Simulator loopback 専用の保険」として温存すれば既存設計を一切歪めない**。

### 4. Python 版 B の去就 → **移行1サイクルは併走、Swift 版がパリティ＋テスト確立後に廃止**
- 現 Python 版は CI で pytest 59 PASS（うち `ipc_helpers.py` 純関数 unit を含む）の検証実績がある。
  いきなり廃止せず、Swift 版が ①4ツール live パリティ ②同等の L1 テスト ③実機 e2e 検証 を満たすまで
  reference / CI 安全網として残すのが当事者推奨。
- パリティ確認後は Python を廃止（または `examples/` へ降格）してよい。**二系統の恒久併存は避ける**
  （venv 撲滅という当初目的と矛盾するため）。CI も Swift テストへ寄せ替える前提。

### 5. SPM 公開の前提整備 → **semver タグ起票=S・public API 監査=（0.x なら S / 1.0 目標なら M）**
- **git tag: 現状 0 件（裏取り済み）。version pin 不可**。まず semver 起票（例 v0.1.0）が必須。タグ運用自体は S。
- public API 監査: library は `public` 面が広い（TestableServer / PerformRequest / JSONValue / AnyTestable /
  各 Core / TestableEnvironment・View）。**当面は 0.x タグで pin（exact）すれば ProjectDeck 取り込みは可能＝S**。
  1.0 を切る段階で「真に public か internal か」の整理・doc comment・access 制御の絞り込みが要る＝M。
- 推奨ステップ: ①今すぐ v0.x タグ付与し exact pin で ProjectDeck 連携を解禁 →
  ②Swift MCP・全PJ展開が固まってから 1.0 public API 監査、の2段。

### 総括
1〜5 いずれも **技術的に実現可能**。律速は工数ではなく **(a) 外部依存ゼロ方針の扱い（target 分離で封じ込め可）**
と **(b) semver タグ未整備（要・即起票）**。Swift 化の便益は venv 消滅／SPM 配布／単一言語であり、
in-process 化ではない点を §6 #3 に明記すれば認識整合する。実装着手は別途合意後。
