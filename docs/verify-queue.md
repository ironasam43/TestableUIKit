# verify-queue（TestableUIKit）

> DoD で完了とした改修のうち、**効果をビルド/テストで断定できないもの**を人間が「使っているうちに」確認するキュー。
> test-strategy.md（層の役割）／manual-check.md（L5 恒常カテゴリ）とは別物。混ぜない。

## 書式（先頭ビルド＋3クローズ＋詳細退避）
- `- [ ] **build NNN** ｜操作: … ｜着眼: … ｜合格: …`（1行目＝人間用スキャン行）
- `    └ 詳細: 真因候補・背景・Reopen 根拠など（任意・2行目＝エージェント用）`
- 先頭は必ず **build NNN**（太字）。build に紐づかない残余はラベル太字で代替。本体は 操作／着眼／合格 の3クローズのみ。「正しく表示」だけの曖昧記述は禁止。

## 状態モデル（3状態）
- **Open**: `[ ] **build NNN** ｜操作: … ｜着眼: … ｜合格: …`
- **Done**: `[x] **build NNN** ✅YYYY-MM-DD ｜…`
- **Reopen（着手筆頭）**: `[ ] 🔁Reopen YYYY-MM-DD（was ✅YYYY-MM-DD）**build NNN** ｜…理由` … `🔁` を SessionStart hook が冒頭注入。
- ✅ Done のまま **2日経過**した行は節目スキャン時に `verify-queue-done.md` へ自動退避（✅ 直後は消えない）。
- 後続改修で対象が消え確認不能になった Open 行は単純削除し `docs/history.md` に1行残す。

---

- [ ] **MCP Swift 版 4ツール live パリティ** ｜操作: 実機（`TESTABLE_IPC_HOST=<実機IP> cd mcp-swift && swift run TestableUIKitMCP`）or Simulator（`swift run TestableUIKitMCP`）で起動した MCP サーバに ui_ping→ui_getState(`scene.demo.counter`)→ui_perform(increment)→ui_getState→ui_screenshot を順に呼ぶ ｜着眼: 各ツールの戻り値 ｜合格: ui_ping=`{"status":"ok"}`／getState=describedState dict／perform 後 count 0→1／screenshot=非空 PNG。Python 版と同一結果（パリティ成立）
    └ 詳細: protocol-level（stdio handshake・tools/list・tools/call の graceful fail）と Core 純関数 41 XCTest は機械検証済み。残るは起動中 DemoApp への実 HTTP 中継成功パス。合格後 Python 版 `mcp_server/` 廃止条件①を満たす。

## 機械検証済み・消し込み
