# verify-queue.md

> 機械検証で効果を断定できない改修の残余起票ファイル。
> 人間が「使っているうちに」確認 → 効いていれば `[x] ✅日付`、直っていなければ Reopen（理由付記）。

## 未確認

- [ ] **STEP 2 Counter pytest CI 実行**: DemoApp をシミュレータで起動後、`pytest Tests/test_swiftui_counter.py` を実行し、①全30テストが PASS すること、②Counter の getState→increment→getState が HTTP IPC で正しく状態遷移（count: 0→1→2 等）することを確認する。（2026-06-22）
