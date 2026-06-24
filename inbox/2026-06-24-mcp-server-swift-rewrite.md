# B（MCP サーバ）Swift 化・SPM 公開 — 実装着手依頼

- **発生元**: Dev/ HQ タブ（Executive Orchestrator）
- **日付**: 2026-06-24
- **消化モード**: フロー（Phase1 分析→BB→CM承認→実装の cmflow で処理。設計判断を含むため）

## 背景

HQ `docs/test-strategy.md` §6 #3（MCP 実装場所・最終確定 2026-06-24）と、TUK 側の照会回答（`docs/history.md` 2026-06-24「B Swift 化・SPM 公開の可否照会 回答」検収済み）で**方向性は合意済み**。今セッションで律速2点のうち (b) semver タグが `v0.1.0`（local＋remote）で解消され、SPM exact pin が解禁された。残るのは §6#3 の本体である **B（現 Python MCP サーバ）の Swift 化** ＝ ロードマップ段階 B の完了。

現状:
- 現 B＝`mcp_server/testableui_mcp.py`（178行）＋ `ipc_helpers.py`（純粋ヘルパー）＝**状態レス HTTP↔MCP 中継・固有ロジックなし**。層の境界は MCP ではなく HTTP（:8888）。
- 依存: `mcp>=1.0.0` / `requests>=2.28.0`（venv 必須）。
- `Package.swift` は外部依存ゼロを差別化として明記（library C の維持条件）。

## 修正対象・要求内容

**B を Python から Swift MCP サーバへ書き直し、SPM パッケージとして公開する。** 既存照会回答（history 2026-06-24）で確定済みの設計方針に従う:

1. **MCP Swift SDK で 4 ツールを再実装**（`ui_ping` / `ui_getState` / `ui_perform` / `ui_screenshot`）。FastMCP 相当の自動 schema 推論は無いため Tool を手動登録するが、schema は単純で軽い。
2. **外部依存ゼロ方針の維持（必須条件）**: swift-sdk 導入は **MCP executable target に封じ込め**、`TestableUIKit` library（C）の依存ゼロは堅持する。`Package.swift` に MCP 用 `.executableTarget`（仮: `TestableUIKitMCP`）を追加し、その target にのみ swift-sdk 依存を付ける。
3. **アーキテクチャ（確定）**: in-process 化ではなく「SPM パッケージを取り込み executable をビルドし、**stdio MCP ↔ HTTP(:8888) ブリッジを別プロセスとして spawn する**」構成。Python 版と同じく HTTP 越しに DemoApp/実機を駆動する。
4. **screenshot 経路**: 既存 `GET /screenshot`（app 側 provider）を一次経路に。simctl fallback（Simulator 限定）は `Process` で移植可・設計不変。実機は provider 経路で吸収。
5. **Python 版の扱い**: パリティ（4ツール挙動一致）＋テスト確立まで**併走**し、その後 `mcp_server/`（Python）を廃止する（恒久併存は避ける）。

## 完了条件（検収必要）

1. `Package.swift` に MCP executable target を追加し、swift-sdk 依存をその target に封じ込め（library の外部依存ゼロを `swift build` で確認）。
2. 4 ツール（ping/getState/perform/screenshot）を Swift で実装し、**実機 or Simulator で e2e 駆動実証**（Python 版 3/4〜4/4 と同等のパリティ）。
3. ロジック分割可能部（payload 組み立て・state passthrough・URL 構築等＝現 `ipc_helpers.py` 相当）を純粋関数化し **XCTest で機械検証**（DoD ゲート②）。
4. Python 版 → Swift 版の切替手順を `docs/`（design or roadmap）に明文化。パリティ確認後の Python 版廃止可否を判断・記録。
5. `swift build` / `swift test` green・規約プレフィックスでコミット・`docs/history.md` 追記。
6. semver: 段階② の 1.0 public API 監査はスコープ外（0.x 系のまま）。本チケットは段階 B（Swift 化）の完了が DoD。

## 検収

**必要**（設計判断＋外部依存導入を含むため）。完了時 `inbox/done/` へ移動 → `sendNote(kind: done)` で HQ（Dev）タブへ通知してください。HQ が `Package.swift` の依存封じ込め・e2e パリティ・テスト機械検証を確認して `accepted`/`rejected` を返します。

## 参考（HQ 側資料）

- `Dev/docs/test-strategy.md` §6 #3（2026-06-24 確定）・§5 ロードマップ段階 B・§7 全PJ展開律速
- 本リポ `docs/history.md` 2026-06-24「B Swift 化・SPM 公開の可否照会 回答」（設計詳細の一次源）
