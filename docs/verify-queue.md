# verify-queue.md

> 機械検証で効果を断定できない改修の残余起票ファイル。
> 人間が「使っているうちに」確認 → 効いていれば `[x] ✅日付`、直っていなければ Reopen（理由付記）。

## 未確認

- [x] ✅2026-06-23 **Design D — 実機 Wi-Fi 越し実通信確認**（実機疎通 成立）: 実機 iPhone へ DEBUG ビルド（`b66a831`）を再インストール → 起動ログに `✅ TestableServer listening on http://0.0.0.0:8888` を確認 → Mac から `curl http://192.168.0.181:8888/ping` が `{"status":"ok"}` を返却（exit 0）。**合格**：Wi-Fi 越し HTTP IPC 疎通が成立。DemoApp の `#if DEBUG` LAN 公開実装（`b66a831`）を実機へ再インストール後、Mac から Wi-Fi 越しで HTTP IPC が疎通することを確認。**検証手順**：① iPhone を Wi-Fi に接続し LAN IP を確認（現在の実機 IP 例: `192.168.0.181`）→ ② `project.yml` で signing/device 設定後 `xcodegen` ＆ Xcode で DEBUG ビルドを実機へインストール（Human が実施）→ ③ DemoApp を実機で起動（起動ログに `TestableServer started on 0.0.0.0:8888` が表示されること）→ ④ Mac で `export TESTABLE_IPC_HOST=192.168.0.181` を設定し `python3 -c "from mcp_server.ipc_helpers import resolve_ipc_host_port; import requests; r = requests.get(resolve_ipc_host_port() + '/ping'); print(r.json())"` を実行 → ⑤ `{"status":"ok"}` が返却されることを確認。**補足**：MCP tool 経由の場合は `TESTABLE_IPC_HOST=192.168.0.181 python3 mcp_server/testableui_mcp.py` 起動後に `ui_ping` を呼ぶ。**合格条件**：Mac 側コンソールで `{"status": "ok"}` が返却されること。**注意**：Provisioning Profile・デバイス UUID 登録・signing は Human が別途実施。Release ビルドは loopback 固定のため本確認は DEBUG ビルド限定。

- [ ] **STEP 1.5 MCP live PoC 駆動実証**: Simulator で DemoApp を起動し、`python3 mcp_server/testableui_mcp.py` を起動 → `ui_ping` で `{"status":"ok"}` が返ること・`ui_getState("scene.demo.counter")` で describedState dict が返ること・`ui_perform("scene.demo.counter","increment",{})` で count が +1 されること・`ui_screenshot` でスクリーンショットが保存されることの4点を確認。手順：① `xcrun simctl boot` → ② `xcodebuild` で DemoApp ビルド＆インストール → ③ `xcrun simctl launch` → ④ `python3 mcp_server/testableui_mcp.py` 起動 → ⑤ MCP inspector か Python client で上記4ツールを順実行。合格：4ツール全て正常レスポンス返却。

## 機械検証済み・消し込み

- [x] ✅2026-06-22 **STEP 2 Counter pytest CI 実行**: GitHub Actions CI（pytest-ipc ジョブ）で `test_swiftui_counter.py` 21テスト ＋ `test_ipc.py` 10テスト = 合計 31 PASS を確認（run #27926198101）。Counter の getState/increment/decrement/reset/setProperty が HTTP IPC で正しく状態遷移することを機械検証で確認。※件数「30」はドキュメントドリフト、実体は 21 テスト。
