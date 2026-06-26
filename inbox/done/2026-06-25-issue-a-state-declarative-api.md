# 課題A: state 宣言型 高レベル API（Tier 1 汎用ブリッジ ＋ Tier 2 標準コントロール drop-in）

- **発生元**: HQ（Dev/ タブ・対話モード）課題A 設計協議
- **日付**: 2026-06-25
- **消化モード**: フロー（Phase1 分析 → BB → CM 承認 → 実装。新規 public API 設計のため CM 承認を挟む）
- **検収**: 必要（HQ が API 形・ボイラープレート削減効果を一次裏取りして accepted/rejected を返す）

## 背景

TUK の全PJ横展開における唯一残った律速が「計装コストの線形増加（課題A）」。
カスタム UI 1個の計装に現状**3部品**が要る（実例: `Example/MyToggleExample.swift`）：

| 部品 | 内容 | 性質 |
|---|---|---|
| ① Core | state struct ＋ `apply*` 純粋関数 | テスト契約そのもの（消せない） |
| ② AnyTestable ブリッジ | `@Published`↔Core・`perform` の手書き switch（getState/toggle/setProperty…） | ほぼ定型ボイラープレート |
| ③ アプリ配線 | Registry/Server 注入 | アプリにつき1回（per-component ではない） |

線形増加（コンポーネント数×手作業）の犯人は **②の手書き switch**。③は1回きり、①は本質的にテスト契約。

**⚠️ 重要な設計確定（HQ 協議・`Dev/docs/test-strategy.md` §7 更新(3) に記録済み）**:
roadmap が当初掲げた「`.testable("id"){ 生Button }` で生 SwiftUI を state 自動抽出で透過ラップ」は
**SwiftUI の制約上 literal には実現不可**と確定。理由＝View は値型で `@State`/binding 内部が不透明。
汎用に覗くには private SwiftUI 型への Mirror リフレクションが必要で、TUK の iOS15 保全・依存ゼロ方針と衝突する。
よって誇大ゴールを廃し、**実現可能な「state 宣言型 高レベル API」2段**へ再定義した（本チケットの要求内容）。

## 修正対象・要求内容

既存の `AnyTestable` プロトコル契約（`Sources/TestableUIKit/AnyTestable.swift`）：
```swift
public protocol AnyTestable: AnyObject, Sendable {
  var testID: String { get }
  var describedState: [String: JSONValue] { get }
  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue]
}
```
これを直接書かせず、以下 2 Tier の高レベル API で覆う。**既存 `AnyTestable` 手書き経路は壊さず温存**（後方互換）。

### Tier 1 — 汎用ブリッジ `TestableComponent`（②を全廃・全カスタム UI に効く本丸）
ブリッジ class を書かせず、state ＋ コマンド表を渡すだけで `AnyTestable` 準拠を自動生成する concrete 型：
```swift
let toggle = TestableComponent(
  id: "example.my.toggle",
  state: MyToggleState(),                       // ①Core はそのまま渡す（テスト契約は残る）
  describe: { ["isOn": .bool($0.isOn)] },       // describedState 相当
  commands: ["toggle": { s, _ in s.isOn.toggle() }]   // perform の switch を表に畳む
)
```
- `getState` / `setProperty` など**汎用コマンドは TUK 側が標準提供**（各コンポーネントで再実装させない）。
- `describe` は省略時に Mirror で state の stored property を自動 describe するフォールバックを検討可（カスタム UI の自前 state は値型なので Mirror 可。private SwiftUI 型は覗かない＝OS 依存しない）。
- → ②の手書き switch が消滅。残るのは①（state＋意味論＝テスト契約）だけ。

### Tier 2 — 標準コントロール drop-in（①②とも自動導出・ゼロボイラープレート）
SwiftUI 標準コントロールは既存 binding を渡すだけのラッパーを提供：
```swift
TestableToggle("My Toggle", isOn: $isOn, id: "example.my.toggle")
// 同様に TestableTextField / TestableStepper / TestableSlider / TestableButton
```
- binding から state・describe・commands を自動導出（①Core も不要）。
- 「binding を渡す」点だけが「生 View 透過」との差分。これは SwiftUI 不透明性ゆえ**不可避**（生 View からは binding を汎用に取り出せない）。
- 対象セット: Toggle / TextField / Stepper / Slider / Button（最低限。他は追って拡張可）。

## 完了条件（DoD）

1. **L0 ビルド通過**（iOS15 保全・library 依存ゼロを維持。Mirror 使用は自前 state 値型に限定し private SwiftUI 型に触れない）。
2. **Tier 1 `TestableComponent`** が実装され、`Example/MyToggleExample.swift` を **Tier 1 で書き直したサンプル**を同梱（②手書き switch が消えることを実コードで示す）。
3. **Tier 2 drop-in** 5種（Toggle/TextField/Stepper/Slider/Button）を実装し、各1つの最小サンプルを同梱。
4. **テスト追加**（テスト基盤稼働中の PJ）：Tier 1 の describe/commands 経路と Tier 2 の binding 自動導出を、`perform`/`describedState` の round-trip で XCTest 検証（getState→setProperty→getState、toggle コマンド等）。
5. 既存 `AnyTestable` 手書き経路が**従来どおり動作**（後方互換の回帰がない）こと。
6. README / getting-started に 2 Tier の使い分けを追記。
7. コミット（規約プレフィックス）。CURRENT_PROJECT_VERSION は TUK の運用に従う。

## 補足

- 本チケットは `Dev/docs/test-strategy.md` §7「課題A」の再定義（更新 2026-06-25(3)）と一対。設計の正本はそちら。
- パイロット選定（本番 iOS SwiftUI PJ）は別レーン。本 API が固まれば横展開の計装コスト線形増加が畳まれる。
