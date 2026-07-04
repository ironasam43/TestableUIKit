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

- [ ] **macOS Demo e4bfb1f** ｜操作: `swift run TestableUIKitMacDemo` でデモ起動 → ウィンドウの5コンポーネント（Counter/TextInput/OnOffSwitch/RangeSlider/Button）を目視 ｜着眼: レイアウト崩れ・重なり・テキスト欠落がないか ｜合格: 全5コンポーネントが可読な状態で縦並びに表示されている
    └ 詳細: signature/寸法/byte長/実描画の機械確認は完了（1800×1364px @2x・46,280bytes・PNG✅）。残るのは「見た目の正しさ」のみ。HTTP e2e（ping/getState/perform/screenshot）はすべてログで断定済み。
- [ ] **macOS Demo e4bfb1f** ｜操作: `swift run TestableUIKitMacDemo` 起動後、画面上ボタン（Increment・Login・Apply 等）をクリック ｜着眼: ボタン押下がサーバ側 perform と同等の状態変化を UI に反映するか ｜合格: カウンタ加算・スライダ反映など UI が即座に更新される
    └ 詳細: HTTP POST /perform(increment) での 0→1 は e2e 断定済み。残るは GUI クリック → SwiftUI @State 更新の配線確認（HTTP 非経路・目視のみ）。
- [ ] **MCP Swift 版 4ツール live パリティ** ｜操作: 実機（`TESTABLE_IPC_HOST=<実機IP> cd mcp-swift && swift run TestableUIKitMCP`）or Simulator（`swift run TestableUIKitMCP`）で起動した MCP サーバに ui_ping→ui_getState(`scene.demo.counter`)→ui_perform(increment)→ui_getState→ui_screenshot を順に呼ぶ ｜着眼: 各ツールの戻り値 ｜合格: ui_ping=`{"status":"ok"}`／getState=describedState dict／perform 後 count 0→1／screenshot=非空 PNG。Python 版と同一結果（パリティ成立）
    └ 詳細: protocol-level（stdio handshake・tools/list・tools/call の graceful fail）と Core 純関数 41 XCTest は機械検証済み。残るは起動中 DemoApp への実 HTTP 中継成功パス。合格後 Python 版 `mcp_server/` 廃止条件①を満たす。
- [ ] **ui_runScenario 37e835d** ｜操作: 実機/Simulator で起動した DemoApp に対し `swift run TestableUIKitMCP` の `ui_runScenario` へ `Example/scenarios/counter-flow.json` を渡して実行 ｜着眼: 各ステップの pass/fail ｜合格: 5 ステップ全て `passed: true`（`passCount=5, failCount=0`）
    └ 詳細: パース・assert 評価（`ScenarioEvaluator`）は L1 XCTest 20件で機械検証済み。DemoApp 未起動時の graceful fail（HTTP 接続失敗でもシナリオ中断せず5ステップ完走・fail 記録）は stdio 経由で実測確認済み。残るは起動中 DemoApp への実 HTTP 中継が pass する成功パスのみ。
- [ ] **シナリオ・オーサリング支援（21943ef）** ｜操作: scenario.schema.json・docs/scenario-authoring.md が存在し、AI が MCP 接続時に `ui_runScenario` のスキーマおよびオーサリングドキュメントを参照できる状態で、テスト用シナリオ（Example/scenarios/*.json 以外の独自シナリオ）を JSON で作成 ｜着眼: 作成されたシナリオが schema に valid か ｜合格: `ajv` など JSON Schema validator で scenario.schema.json に照合し validate: true（enum 値・require キー・parameters 形式が schema 仕様に合致）
    └ 詳細: schema enum・MCP inputSchema・L1 テスト（ScenarioActionTests）は機械検証済み（swift test 117 PASS）。残るは AI がドキュメントとスキーマを活用して「勘ではなく仕様準拠」にシナリオを記述できるかの体感・実用検証。JSON validator で形式チェック後、実アプリ稼働時に実際の e2e 成功パスは同一 VQ へ統合確認可。

## 機械検証済み・消し込み
