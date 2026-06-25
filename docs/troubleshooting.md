# Troubleshooting

TestableUIKit の利用中に遭遇しやすい問題と対処をまとめます。
セットアップ手順は [`SETUP.md`](../SETUP.md)、計装手順は [`docs/getting-started.md`](getting-started.md) を参照してください。

---

## サーバ起動・接続

### `✅ TestableServer listening on ...` が表示されない

サーバが起動していません。

1. アプリ（DemoApp / 自作アプリ）が Simulator・実機で起動しているか確認。
2. `.task { server.start() }` が呼ばれているか、`TestableServer` の生成が `try?` で握り潰されていないか確認。
3. Xcode の Console タブでログを確認。

### `Connection refused` / `Server not reachable`

サーバが対象ホスト・ポートで listen していません。

1. Xcode コンソールに `✅ TestableServer listening on http://<host>:8888` が出ているか確認。
2. Simulator の場合: `localhost:8888` でアクセス。実機の場合: `#if DEBUG` で `host: "0.0.0.0"` 公開し、実機 IP を指定（下記「実機（LAN 越し）」）。
3. Simulator を再起動（`Xcode > Device > Erase All Content and Settings...`）。
4. ファイアウォール確認（`System Settings > Network > Firewall`）でポート 8888 がブロックされていないか確認。

### ポート 8888 競合（多重起動・別プロセスが使用中）

既に 8888 を掴むプロセスがあると、`TestableServer.start()` は ready にならず
`.failed`（`POSIXErrorCode 48: Address already in use`）になります。

**検知**: `onStateChange` でプログラム的に検知できます（従来は print のみで検知不能でした）。

```swift
let server = try TestableServer(port: 8888, registry: registry)
server.onStateChange = { state in
  switch state {
  case .ready:        print("listening")
  case .failed(let e): print("起動失敗（ポート競合の可能性）: \(e)")  // ここでフォールバック等
  case .cancelled:    print("stopped")
  default: break
  }
}
server.start()
```

**対処**:

1. 競合プロセスを特定して終了する。
   ```bash
   lsof -i :8888
   kill <PID>
   ```
2. 別ポートで起動する（`TestableServer(port: 8889, registry:)`）。利用側の `TESTABLE_IPC_PORT` も合わせる。
3. 前回起動したアプリ・サーバが残っていないか確認（多重起動）。`server.stop()` を呼んで graceful shutdown すると
   ポートが解放され、`.cancelled` が `onStateChange` に届きます。

### `Connection refused` だが ping は通る（`component not found` / 404）

`POST /perform` で 404（`component not found`）になる場合、最も多い原因は **Registry 共有もれ**です。
`.environment(\.testableRegistry, registry)` を注入し忘れると、`.testable(_:)` は空の defaultValue registry へ
登録され、サーバの registry とは別物になります。アプリ起点で生成した同一 `registry` を
**サーバと View ツリーの両方**へ渡してください（[`getting-started.md`](getting-started.md) 既知の罠①）。

---

## テストランナー（Python）

### `No module named 'requests'`

```bash
pip3 install requests
```

### `curl: command not found`

macOS には curl がデフォルト同梱です。PATH を確認します。

```bash
which curl   # => /usr/bin/curl と表示されれば OK
```

### Python test が `Connection refused`

1. Xcode で Run し、Simulator・実機でアプリ起動を確認。
2. コンソールに `✅ TestableServer listening ...` が出るまで待つ。
3. `python3 run_test.py` を実行。

---

## 実機（LAN 越し）

### `Connection refused`（実機）

実機の IP が違うか、DemoApp が起動していません。

1. 実機で DemoApp が起動していることを確認。
2. 実機の IP を再確認（設定 > Wi-Fi > 情報）。
3. Xcode コンソールに `✅ TestableServer listening on http://0.0.0.0:8888` が出ているか確認。
4. 接続先を実機 IP に指定: `TESTABLE_IPC_HOST=192.168.x.x python3 ...`。

### `Timeout`（実機）

実機と Mac が通信できていません。

1. **Wi-Fi**: 両者が同じネットワークに接続しているか確認。
2. **ファイアウォール**: Mac のファイアウォールでポート 8888 がブロックされていないか確認。
3. **ネットワーク隔離**: 企業 Wi-Fi など、デバイス間通信が制限されていないか確認。

### `RuntimeError: simctl not available on a non-loopback host`

実機への接続は成功し、screenshot の simctl フォールバック時に出るログです。

- このエラーは無視できます。実機からの `GET /screenshot`（経路A・アプリ内キャプチャ）で
  既に PNG が取得できています。
- `simctl` フォールバックは Simulator（loopback）のみ有効です。
- 経路の詳細は [`SETUP.md`](../SETUP.md) ステップ 7-5 を参照。

---

## コンポーネント挙動

### `isEnabled が false` でコマンドが no-op になる

多くの Core は `isEnabled == false` のとき増減コマンドを no-op にします。
`setProperty` で `isEnabled` を `true` に戻すか、初期化時に有効化してください。

```swift
// IPC で有効化する例
// {"commandName":"setProperty","parameters":{"key":"isEnabled","value":true}}
```
