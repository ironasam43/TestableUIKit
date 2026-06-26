# Getting Started — 5分で自作コンポーネントを計装する

TestableUIKit は、SwiftUI コンポーネントが **自分の状態とコマンドを自己申告** し、
HTTP IPC（`localhost:8888`）経由で外部（テストランナー・AI エージェント）から
操作・検証できるようにするフレームワークです。

このガイドでは、自作の SwiftUI コンポーネントを **3 ステップ**で計装します。
所要時間は約 5 分です。

> 前提: Swift Package Manager を使えること。詳細な Xcode セットアップは [`SETUP.md`](../SETUP.md) を参照。

---

## 3 つの API 段階（どれを使うか）

計装の書き方には抽象度の異なる 3 段階があります。**まず上から検討**し、合わなければ下に降りてください。

| Tier | API | 向いている対象 | 必要な部品 |
|---|---|---|---|
| **Tier 2** | `TestableToggle` / `TestableTextField` / `TestableStepper` / `TestableSlider` / `TestableButton` | 標準 SwiftUI コントロール | View を差し替えるだけ（state 値型もブリッジも不要） |
| **Tier 1** | `TestableComponent<State>` | 自作コンポーネント（state 値型を持つ） | state 値型 ＋ `properties` / `commands` の宣言（手書き `perform` switch 不要） |
| **Tier 0** | `AnyTestable` 手書き準拠 | 特殊な計装（ロック制御・cross-process 等） | `testID` / `describedState` / `perform` を自前実装 |

- **Tier 2**: 標準コントロールなら最速。`TestableToggle("通知", isOn: $isOn, id: "x")` のように書くだけで自動計装されます（後述「Tier 2」）。
- **Tier 1**: 自作 state を持つコンポーネントは `TestableComponent<State>` を宣言します。`describe` 省略時は `properties`、それも無ければ Mirror で値型プロパティ（Bool/Int/Double/String）を自動 describe します（後述「Tier 1」）。
- **Tier 0**: 以降の「全体像（3 つの部品）」が Tier 0 の書き方です。最大の自由度が要るときだけ使います。

---

## Tier 2：標準コントロールを即計装する

標準 SwiftUI コントロールは、対応する `Testable*` View へ置き換えるだけで計装できます。

```swift
import TestableUIKit

struct SettingsView: View {
  @State private var isOn = false
  @State private var name = ""
  @State private var qty = 0

  var body: some View {
    VStack {
      TestableToggle("通知", isOn: $isOn, id: "settings.toggle")
      TestableTextField("名前", text: $name, id: "settings.name")
      TestableStepper("数量: \(qty)", value: $qty, id: "settings.qty")
      TestableButton("保存", id: "settings.save") { /* action */ }
    }
    .environment(\.testableRegistry, registry)  // ★ registry 注入は Tier 0/1 と同じ
  }
}
```

各コントロールが受け付けるコマンド:

| View | コマンド | describe キー |
|---|---|---|
| `TestableToggle` | `toggle` / `setProperty` | `isOn` |
| `TestableTextField` | `setProperty` | `text` |
| `TestableStepper` | `increment` / `decrement` / `setProperty` | `value` |
| `TestableSlider` | `setProperty` | `value` |
| `TestableButton` | `tap` | `tapCount` |

> registry 注入（`.environment(\.testableRegistry, registry)` ＋ サーバへ同じ registry）は全 Tier 共通です（後述ステップ 3）。動くサンプルは [`Example/StandardControlsExample.swift`](../Example/StandardControlsExample.swift)。

---

## Tier 1：自作コンポーネントを `TestableComponent` で計装する

自作の state 値型を持つコンポーネントは、手書きの `AnyTestable` ブリッジ class を書かずに
`TestableComponent<State>` を宣言するだけで計装できます。

```swift
import TestableUIKit

struct MyToggleState { var isOn = false }

struct MyToggleView: View {
  @StateObject private var toggle = TestableComponent<MyToggleState>(
    id: "example.my.toggle",
    state: MyToggleState(),
    properties: ["isOn": .bool(\.isOn)],            // describe ＋ setProperty を自動生成
    commands: ["toggle": { s, _ in s.isOn.toggle() }]
  )

  var body: some View {
    Toggle("My Toggle", isOn: Binding(
      get: { toggle.state.isOn },
      set: { _ in Task { _ = try? await toggle.perform(commandName: "toggle", parameters: .null) } }
    ))
    .testable(toggle)
  }
}
```

- `properties`: `TestableProperty<State>` の辞書。`.bool/.int/.double/.string(\.keyPath)` で KeyPath から get/set を自動生成（型不一致は throw）。
- `commands`: コマンド名 → `(inout State, JSONValue) throws -> Void`。
- `describe`: 省略すると `properties` → なければ Mirror フォールバック（値型プロパティのみ）で導出。
- `getState` / `setProperty` は自動でハンドリングされます。

> 動くサンプルは [`Example/MyToggleExample.swift`](../Example/MyToggleExample.swift)。旧版で必要だった「手書き `AnyTestable` ブリッジ class（`perform` の switch）」は不要になりました。

---

## 全体像（3 つの部品）

> ここからは **Tier 0（`AnyTestable` 手書き）** の書き方です。Tier 1/2 で足りない特殊計装のときに使います。

計装に必要なのは次の 3 つです。

1. **`*Core.swift`（純粋ロジック）** — 状態 struct ＋ コマンド処理関数。テスト容易な値型で書く。
2. **`AnyTestable` 準拠クラス** — `testID` / `describedState` / `perform(...)` を実装し、Core を呼ぶ薄いブリッジ。
3. **Registry 注入 ＋ `.testable(_:)`** — アプリ起点で生成した 1 つの `TestableRegistry` を
   サーバと View ツリーの両方へ注入し、View に `.testable(component)` を付けて自動登録する。

---

## ステップ 1：依存を追加する

`Package.swift`（または Xcode の Package Dependencies）に追加します。

```swift
.package(url: "https://github.com/ironasam43/TestableUIKit", from: "0.1.0")
```

ターゲットの dependencies に `"TestableUIKit"` を加えます。

---

## ステップ 2：コンポーネントを `AnyTestable` 準拠にする

例として「カウンター」を計装します。まず純粋ロジック（Core）を分離します。

```swift
import TestableUIKit

// --- Core（純粋な値型・テスト容易） ---
struct CounterState { var count = 0; var isEnabled = true }

func makeDescribedState(_ s: CounterState) -> [String: JSONValue] {
  ["count": .int(s.count), "isEnabled": .bool(s.isEnabled)]
}
func applyIncrement(to s: inout CounterState) { if s.isEnabled { s.count += 1 } }
```

次に `AnyTestable` 準拠のブリッジクラスを書きます。
`@Published` プロパティと Core struct を相互変換し、`perform` でコマンドを Core へ委譲します。

```swift
@MainActor
final class Counter: ObservableObject, AnyTestable {
  let testID = "scene.demo.counter"   // 一意な ID。IPC でこの ID を指定して操作する
  @Published var count = 0
  @Published var isEnabled = true

  private var _state: CounterState {
    get { var s = CounterState(); s.count = count; s.isEnabled = isEnabled; return s }
    set { count = newValue.count; isEnabled = newValue.isEnabled }
  }

  var describedState: [String: JSONValue] { makeDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState": return describedState
    case "increment": var s = _state; applyIncrement(to: &s); _state = s; return describedState
    default: throw TestError.unknownCommand(commandName)
    }
  }
}
```

> **ポイント**: ロジックを Core（純粋関数）に寄せると、`perform` を経由せず Core 関数を
> 直接 XCTest で検証できます（テストピラミッド L1）。ブリッジは薄く保ちます。

---

## ステップ 3：Registry を注入し、View に `.testable(_:)` を付ける

アプリ起点で **1 つだけ** `TestableRegistry` を生成し、**サーバと View ツリーの両方へ同じインスタンスを注入**します。
これが計装で最も間違えやすい箇所です（下記「既知の罠」参照）。

```swift
@main
struct MyApp: App {
  @StateObject private var counter = Counter()
  @State private var registry = TestableRegistry()   // ★ アプリ起点で 1 つ生成
  @State private var server: TestableServer?

  var body: some Scene {
    WindowGroup {
      CounterView(counter: counter)
        .testable(counter)                            // ★ View 表示時に自動登録
        .environment(\.testableRegistry, registry)    // ★ View ツリーへ同じ registry を注入
        .task {
          let s = try? TestableServer(port: 8888, registry: registry)  // ★ サーバへ同じ registry
          s?.start()
          server = s
        }
    }
  }
}
```

これで完成です。アプリを起動すると `✅ TestableServer listening on http://127.0.0.1:8888` が
コンソールに出ます。

---

## 動作確認

別ターミナルから疎通・状態取得・コマンド実行を確認できます。

```bash
# 疎通確認
curl http://localhost:8888/ping
# => {"status":"ok"}

# 状態取得（getState）
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"scene.demo.counter","commandName":"getState","parameters":null}'
# => {"count":0,"isEnabled":true}

# increment 実行
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"scene.demo.counter","commandName":"increment","parameters":null}'
# => {"count":1,"isEnabled":true}
```

IPC プロトコルの全仕様は [`docs/ipc-protocol.md`](ipc-protocol.md) を参照してください。

---

## 既知の罠

### ① Registry 共有もれ（最頻出・サイレント失敗）

`.environment(\.testableRegistry, registry)` の注入を忘れると、`.testable(_:)` は
**defaultValue の空 registry**（サーバの registry とは別物）へ登録します。
このときエラーは出ず、サーバ側で `component not found`（404）になります。

**対策**: アプリ起点で生成した同一 `registry` インスタンスを、必ず
**サーバ（`TestableServer(registry:)`）と View ツリー（`.environment`）の両方**へ渡すこと。

### ② `testID` の重複

同じ `testID` を複数コンポーネントに付けると、後勝ちで上書きされます。
シーン・役割が分かるよう一意な命名（例: `scene.demo.counter`）にしてください。

### ③ ポート 8888 競合

既に 8888 を使うプロセスがあると `TestableServer` の起動が `.failed` になります。
`server.onStateChange` で検知できます（[`docs/troubleshooting.md`](troubleshooting.md) 参照）。

---

## 次に読むもの

- 最小の動くサンプル: [`Example/`](../Example/README.md)
- IPC プロトコル仕様: [`docs/ipc-protocol.md`](ipc-protocol.md)
- 困ったとき: [`docs/troubleshooting.md`](troubleshooting.md)
- 設計の背景: [`docs/design.md`](design.md)
