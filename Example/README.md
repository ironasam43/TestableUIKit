# Example — 自分のコンポーネントをテストする最小サンプル

このディレクトリは「自作 SwiftUI コンポーネントを TestableUIKit で計装する」最小サンプルです。
`MyToggleExample.swift` 1 ファイルに、計装に必要な 3 部品（Core / `AnyTestable` ブリッジ / アプリ配線）が
すべて収まっています。コピペして自分のプロジェクトの出発点にしてください。

> このディレクトリは **Swift Package のビルド対象外**（`Sources/` の外）です。
> ドキュメント・コピペ用リファレンスとして配置しています。実際に動かす手順は
> [`docs/getting-started.md`](../docs/getting-started.md) を参照してください。

## ファイル

- `MyToggleExample.swift` — トグル（ON/OFF スイッチ）を計装した完結サンプル。

## 計装の 3 部品（おさらい）

1. **Core（純粋ロジック）**: 状態 struct ＋ コマンド処理関数。XCTest で直接検証できる値型。
2. **`AnyTestable` ブリッジ**: `testID` / `describedState` / `perform(...)` を実装し Core を呼ぶ薄いクラス。
3. **配線**: アプリ起点で 1 つの `TestableRegistry` を生成し、`TestableServer` と
   `.environment(\.testableRegistry,)` の **両方へ同じインスタンス**を注入。View に `.testable(_:)` を付与。

## 動作確認（このトグルを IPC で操作する）

```bash
# 状態取得
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"example.my.toggle","commandName":"getState","parameters":null}'
# => {"isOn":false}

# toggle 実行
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"example.my.toggle","commandName":"toggle","parameters":null}'
# => {"isOn":true}
```

困ったら [`docs/troubleshooting.md`](../docs/troubleshooting.md) を参照してください。
