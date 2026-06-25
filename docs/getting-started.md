# Getting Started — 5分で自作コンポーネントを計装する

TestableUIKit は、SwiftUI コンポーネントが **自分の状態とコマンドを自己申告** し、
HTTP IPC（`localhost:8888`）経由で外部（テストランナー・AI エージェント）から
操作・検証できるようにするフレームワークです。

このガイドでは、自作の SwiftUI コンポーネントを **3 ステップ**で計装します。
所要時間は約 5 分です。

> 前提: Swift Package Manager を使えること。詳細な Xcode セットアップは [`SETUP.md`](../SETUP.md) を参照。

---

## 全体像（3 つの部品）

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
