# verify-queue.md

> 機械検証で効果を断定できない改修の残余起票ファイル。
> 人間が「使っているうちに」確認 → 効いていれば `[x] ✅日付`、直っていなければ Reopen（理由付記）。

## 未確認

- [ ] **MCP サーバ Swift 版（`mcp-swift/`）の 4 ツール live パリティ（実機/Simulator）**: protocol-level（stdio handshake・tools/list・tools/call の graceful fail）と Core 純関数 41 XCTest は機械検証済み。残るは**起動中 DemoApp に対する実 HTTP 中継の成功パス**。**操作**: DemoApp を実機（`TESTABLE_IPC_HOST=<実機IP> cd mcp-swift && swift run TestableUIKitMCP`）または Simulator（`swift run TestableUIKitMCP`）で起動した MCP サーバに、MCP クライアント（Claude 等）から ui_ping→ui_getState(`scene.demo.counter`)→ui_perform(increment)→ui_getState→ui_screenshot を順に呼ぶ。**見る所**: ui_ping=`{"status":"ok"}`／getState=describedState dict／perform 後に count が 0→1／screenshot=非空 PNG（image content）。**合格**: 4 ツールが Python 版と同一結果を返すこと（パリティ成立）。合格後、Python 版 `mcp_server/` 廃止条件①を満たす。
- [x] ✅2026-06-23 **STEP 1.5 残 — `ui_screenshot` の実機未対応（設計ギャップ）**: `ui_screenshot` は `build_simctl_screenshot_command` → `simctl io booted screenshot`（Simulator 専用）ハードコードのため**実機では原理的に取得不可**。3/4 ツール（ping/getState/perform）は実機 live で確認済み（消し込み欄参照）だが screenshot のみ未達。残作業の選択肢：(a) Simulator で DemoApp を起動し `ui_screenshot` の PNG base64 返却を確認（既存実装のまま Simulator 限定で合格扱い）／(b) 実機対応のスクリーンショット経路を新規実装（`xcrun devicectl` 等）。**検証手順**：選んだ経路で DemoApp 起動 → MCP `ui_screenshot` 呼び出し → 戻り値に `image_base64`（非空）・`format:"png"` が含まれることを確認。**合格**：PNG base64 が返却されること。

## 機械検証済み・消し込み

- [x] ✅2026-06-23 **STEP 1.5 MCP live PoC（3/4 ツール・実機 live 駆動）**: 実機 iPhone（`192.168.0.181`・DEBUG ビルド `b66a831`・`0.0.0.0:8888` リッスン）に対し MCP tool 関数（`mcp_server/testableui_mcp.py`）を `TESTABLE_IPC_HOST=192.168.0.181` で直接インポート駆動 → `ui_ping`→`{'status':'ok'}`／`ui_getState("scene.demo.counter")`→`{'isEnabled':True,'count':0}`（describedState dict）／`ui_perform(...,"increment")`→`count` が **0→1**／再 `ui_getState`→`{'count':1}`。MCP→HTTP IPC→実機 UI 変異→describedState 反映の e2e を実機で確認。※`ui_screenshot` のみ simctl 依存で実機不可（未確認欄に別行で継続）。
- [x] ✅2026-06-23 **Design D — 実機 Wi-Fi 越し実通信確認**: 実機 DEBUG ビルド（`b66a831`）が起動ログ `✅ TestableServer listening on http://0.0.0.0:8888` で LAN 公開起動、Mac から `curl http://192.168.0.181:8888/ping`→`{"status":"ok"}`（exit 0）。Wi-Fi 越し HTTP IPC 疎通成立（commit `efe964a`）。
