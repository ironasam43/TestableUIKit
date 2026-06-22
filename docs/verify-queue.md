# verify-queue.md

> 機械検証で効果を断定できない改修の残余起票ファイル。
> 人間が「使っているうちに」確認 → 効いていれば `[x] ✅日付`、直っていなければ Reopen（理由付記）。

## 未確認

- [ ] **STEP 1.5 MCP live PoC 駆動実証**: Simulator で DemoApp を起動し、`python3 mcp_server/testableui_mcp.py` を起動 → `ui_ping` で `{"status":"ok"}` が返ること・`ui_getState("scene.demo.counter")` で describedState dict が返ること・`ui_perform("scene.demo.counter","increment",{})` で count が +1 されること・`ui_screenshot` でスクリーンショットが保存されることの4点を確認。手順：① `xcrun simctl boot` → ② `xcodebuild` で DemoApp ビルド＆インストール → ③ `xcrun simctl launch` → ④ `python3 mcp_server/testableui_mcp.py` 起動 → ⑤ MCP inspector か Python client で上記4ツールを順実行。合格：4ツール全て正常レスポンス返却。

## 機械検証済み・消し込み

- [x] ✅2026-06-22 **STEP 2 Counter pytest CI 実行**: GitHub Actions CI（pytest-ipc ジョブ）で `test_swiftui_counter.py` 21テスト ＋ `test_ipc.py` 10テスト = 合計 31 PASS を確認（run #27926198101）。Counter の getState/increment/decrement/reset/setProperty が HTTP IPC で正しく状態遷移することを機械検証で確認。※件数「30」はドキュメントドリフト、実体は 21 テスト。
