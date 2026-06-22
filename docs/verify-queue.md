# verify-queue.md

> 機械検証で効果を断定できない改修の残余起票ファイル。
> 人間が「使っているうちに」確認 → 効いていれば `[x] ✅日付`、直っていなければ Reopen（理由付記）。

## 未確認

- [ ] **Design D 下地 — 実機 Wi-Fi 越し実通信確認**: 実 iPhone をペアリング後に `TestableServer(host: "0.0.0.0")` で DemoApp を起動し、同一 LAN 上の Mac から `TESTABLE_IPC_HOST=<iPhoneのLAN IP>` を設定した pytest / MCP tool で HTTP IPC が疎通することを確認。手順：① iPhone を Wi-Fi に接続しLAN IPを確認（例:192.168.1.x）→ ② `project.yml` で signing/device 設定後 `xcodegen` ＆ Xcode から実機インストール → ③ Mac で `export TESTABLE_IPC_HOST=192.168.1.x` を設定し `python3 run_test.py` 実行 → ④ Phase A（/ping が OK を返す）を確認。合格：`{"status":"ok"}` が返却されること。注：Provisioning Profile・デバイス UUID 登録・signing は Human が別途実施。

- [ ] **STEP 1.5 MCP live PoC 駆動実証**: Simulator で DemoApp を起動し、`python3 mcp_server/testableui_mcp.py` を起動 → `ui_ping` で `{"status":"ok"}` が返ること・`ui_getState("scene.demo.counter")` で describedState dict が返ること・`ui_perform("scene.demo.counter","increment",{})` で count が +1 されること・`ui_screenshot` でスクリーンショットが保存されることの4点を確認。手順：① `xcrun simctl boot` → ② `xcodebuild` で DemoApp ビルド＆インストール → ③ `xcrun simctl launch` → ④ `python3 mcp_server/testableui_mcp.py` 起動 → ⑤ MCP inspector か Python client で上記4ツールを順実行。合格：4ツール全て正常レスポンス返却。

## 機械検証済み・消し込み

- [x] ✅2026-06-22 **STEP 2 Counter pytest CI 実行**: GitHub Actions CI（pytest-ipc ジョブ）で `test_swiftui_counter.py` 21テスト ＋ `test_ipc.py` 10テスト = 合計 31 PASS を確認（run #27926198101）。Counter の getState/increment/decrement/reset/setProperty が HTTP IPC で正しく状態遷移することを機械検証で確認。※件数「30」はドキュメントドリフト、実体は 21 テスト。
