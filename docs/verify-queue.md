# verify-queue.md

> 機械検証で効果を断定できない改修の残余起票ファイル。
> 人間が「使っているうちに」確認 → 効いていれば `[x] ✅日付`、直っていなければ Reopen（理由付記）。

## 未確認

- [ ] **`ui_screenshot` 実機対応 実装済み — 実機での実 PNG 取得確認（commit `78716fd`）**: `GET /screenshot`（provider 注入）経路を実装。`DemoApp` 再インストール後、**①** 実機（`192.168.0.181`）で DEBUG ビルド DemoApp を起動 → **②** `TESTABLE_IPC_HOST=192.168.0.181 python3 -c "import mcp_server.testableui_mcp as m; import asyncio; print(asyncio.run(m.ui_screenshot()))"` を実行 → **③** 戻り値に `image_base64`（非空・有効 base64）・`format:"png"` が含まれることを確認。**合格**: PNG base64 が非空で返却され、base64 デコード後が PNG ヘッダ（`\x89PNG`）で始まること。

## 機械検証済み・消し込み

- [x] ✅2026-06-23 **STEP 1.5 MCP live PoC（3/4 ツール・実機 live 駆動）**: 実機 iPhone（`192.168.0.181`・DEBUG ビルド `b66a831`・`0.0.0.0:8888` リッスン）に対し MCP tool 関数（`mcp_server/testableui_mcp.py`）を `TESTABLE_IPC_HOST=192.168.0.181` で直接インポート駆動 → `ui_ping`→`{'status':'ok'}`／`ui_getState("scene.demo.counter")`→`{'isEnabled':True,'count':0}`（describedState dict）／`ui_perform(...,"increment")`→`count` が **0→1**／再 `ui_getState`→`{'count':1}`。MCP→HTTP IPC→実機 UI 変異→describedState 反映の e2e を実機で確認。※`ui_screenshot` のみ simctl 依存で実機不可（未確認欄に別行で継続）。
- [x] ✅2026-06-23 **Design D — 実機 Wi-Fi 越し実通信確認**: 実機 DEBUG ビルド（`b66a831`）が起動ログ `✅ TestableServer listening on http://0.0.0.0:8888` で LAN 公開起動、Mac から `curl http://192.168.0.181:8888/ping`→`{"status":"ok"}`（exit 0）。Wi-Fi 越し HTTP IPC 疎通成立（commit `efe964a`）。
- [x] ✅2026-06-22 **STEP 2 Counter pytest CI 実行**: GitHub Actions CI（pytest-ipc ジョブ）で `test_swiftui_counter.py` 21テスト ＋ `test_ipc.py` 10テスト = 合計 31 PASS を確認（run #27926198101）。Counter の getState/increment/decrement/reset/setProperty が HTTP IPC で正しく状態遷移することを機械検証で確認。※件数「30」はドキュメントドリフト、実体は 21 テスト。
