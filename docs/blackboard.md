## 課題A: state 宣言型 高レベル API（Tier1 TestableComponent / Tier2 drop-in）
- [x] 問題分析
- [x] Step 1: TestableComponent.swift（Tier1: TestableProperty / runTestablePerform / Mirror describe / TestableComponent）
- [x] Step 2: TestableControls.swift（Tier2: BindingTestable ＋ drop-in 5種）
- [x] Step 3: Example/MyToggleExample.swift を Tier1 で書き直し（②手書き class 削除）
- [x] Step 4: Example/StandardControlsExample.swift 新規（Tier2 5種サンプル）
- [x] Step 5: テスト追加（Tier1 8件 / Tier2 5件 = +13件）
- [x] Step 6: README / getting-started に 3 Tier 使い分け追記
- [x] ビルド確認（swift build エラー0 / swift test 117 PASS・0 failure）
- 備考: 生成 generic `@MainActor ... AnyTestable` は Swift6 言語モードでの ConformanceIsolation **警告**のみ（5.9 モードではビルド/テストともに green。Phase2 [WARN] は実害なしと確認）。
