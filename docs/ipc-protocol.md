# TestableUIKit IPC Protocol Specification

## Overview

TestableUIKit の iOS アプリ ↔ Host PC 間通信は、REST API over HTTP を使用します。  
アプリ内の `TestableServer` が localhost:8888 でリッスンし、テスト自動化ツールはそこへ HTTP リクエストを送信します。

---

## Endpoints

### 1. GET /ping

**目的**: Server 接続確認  
**リクエスト**: なし

**レスポンス**:
```json
{
  "status": "ok"
}
```

---

### 2. POST /perform

**目的**: UI コンポーネント上でコマンドを実行し、状態を取得  
**リクエスト**:

```json
{
  "testID": "string",        // UI コンポーネントの一意識別子
  "commandName": "string",   // 実行するコマンド名
  "parameters": {}           // コマンド固有のパラメータ（dict or null）
}
```

**レスポンス** (success):

> **全コマンド共通**: 成功時は常に以下の **5キー固定の describedState** を返します。

```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**レスポンス** (error):
```json
{
  "error": "string"
}
```

---

## testID Naming Convention

`testID` は階層的に命名し、アプリの View 構造を反映させます。

**形式**: `{scene}.{component}[.{subcomponent}]`

**例**:
- `"scene.auth.loginButton"` — 認証画面の Log In ボタン
- `"scene.dashboard.userCard.editButton"` — ダッシュボード > ユーザーカード > Edit ボタン
- `"scene.settings.toggleSwitch"` — 設定画面のトグルスイッチ

### 実装側での設定

各 UI コンポーネントは `AnyTestable` protocol に準拠し、`testID` フィールドを定義：

```swift
final class LoginButton: ObservableObject, AnyTestable {
  let testID: String = "scene.auth.loginButton"
  // ...
}
```

---

## Standard Commands

### getState

**目的**: コンポーネントの現在の状態をスナップショット取得（副作用なし）  
**パラメータ**: なし

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**実装例**:
```swift
case "getState":
  return describedState
```

---

### tap

**目的**: ボタン等のタップアクション実行  
**パラメータ**: なし

**意味論（S2 確定版）**:
- `isEnabled == false` の場合は **no-op**（実ユーザー同様に弾く）
- 有効時: `isEnabled = false`（二重送信防止）、`title = "Logged In"`（ログイン遷移の結果）

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**実装例** (LoginButton):
```swift
case "tap":
  var state = _state
  applyTap(to: &state)   // guard isEnabled; isEnabled=false; title="Logged In"
  _state = state
  return describedState
```

**tap レスポンス例**（有効時）:
```json
{
  "isEnabled": false,
  "title": "Logged In",
  "isHidden": false,
  "alpha": 1.0,
  "backgroundColor": "systemBlue"
}
```

**tap レスポンス例**（無効時 / no-op）:
```json
{
  "isEnabled": false,
  "title": "Log In",
  "isHidden": false,
  "alpha": 1.0,
  "backgroundColor": "systemBlue"
}
```

---

### setProperty

**目的**: プロパティ値を設定  
**パラメータ**: `{"key": "string", "value": <value>}`

**サポートキー（LoginButton）**:

| key | 型 | 説明 |
|---|---|---|
| `isEnabled` | bool | 有効/無効 |
| `title` | string | ボタンラベル |
| `isHidden` | bool | 表示/非表示 |
| `alpha` | double | 透明度（0.0〜1.0） |
| `backgroundColor` | string | 背景色名（例: "systemBlue"） |

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**実装例**:
```swift
case "setProperty":
  var state = _state
  try applySetProperty(to: &state, parameters: parameters)
  _state = state
  return describedState
```

---

### setEnabled

**目的**: isEnabled を直接設定（bool パラメータ）  
**パラメータ**: `true` または `false`（JSONValue.bool）

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**実装例**:
```swift
case "setEnabled":
  var state = _state
  try applySetEnabled(to: &state, parameters: parameters)
  _state = state
  return describedState
```

---

## Wire Format (JSON Coding)

すべての値は `JSONValue` enum に統合：

```swift
public enum JSONValue: Codable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])
}
```

**リクエスト例（tap コマンド）**:
```python
{
  "testID": "scene.auth.loginButton",
  "commandName": "tap",
  "parameters": null
}
```

**リクエスト例（setProperty コマンド）**:
```python
{
  "testID": "scene.auth.loginButton",
  "commandName": "setProperty",
  "parameters": {
    "key": "isEnabled",
    "value": true
  }
}
```

---

## describedState Format

各 `AnyTestable` 実装は `describedState` を返す際、以下の構造を使用：

```swift
var describedState: [String: JSONValue] {
  makeLoginButtonDescribedState(_state)
}
```

LoginButton（CLI・SwiftUI 共通）の describedState は **5キー固定**：

```json
{
  "isEnabled": true,
  "title": "Log In",
  "isHidden": false,
  "alpha": 1.0,
  "backgroundColor": "systemBlue"
}
```

---

## Error Handling

`TestableServer` 側でエラーが発生した場合：

```swift
throw TestError.unknownCommand(commandName)
throw TestError.componentNotFound(testID)
throw TestError.invalidParameters
```

リクエスター側は HTTP 200 OK で以下を受け取る：

```json
{
  "error": "Unknown command: 'foo'"
}
```

---

## Test Phases（自動テスト検証フェーズ）

TestableUIKit の検証は以下の3段階フェーズで実施：

### Phase A: Network Connectivity
**目的**: Simulator → Host (localhost:8888) の通信確認  
**実行**: `GET /ping`  
**期待**: `{"status": "ok"}`

### Phase B: Logic Verification (UI State Change)
**目的**: UI コンポーネントの状態変化を実証  
**手順**:
1. `/perform` で `getState` コマンド → 初期状態を取得（`isEnabled: true, title: "Log In"`）
2. `/perform` で `tap` コマンド → ログイン遷移を実行
3. `/perform` で `getState` コマンド → 最終状態を取得し、変化を確認

**期待**: 以下の状態遷移が確認される
- `isEnabled: true → false`
- `title: "Log In" → "Logged In"`

**Phase B 実証の意義**: IPC tap → `@Published` 変化（`title` の変化が再描画の証拠）→ SwiftUI 再描画 の全経路を 1 本で通す。

### Phase B-5: Bidirectional Recovery
**目的**: UI 状態の双方向制御と復帰可能性を実証  
**手順**:
1. `/perform` で `tap` コマンド実行後、`isEnabled: false` 状態を確認
2. `/perform` で `setEnabled(true)` コマンド → 状態を初期値に復帰
3. `/perform` で `getState` コマンド → 復帰状態を確認（`isEnabled → true`）

**期待**: `isEnabled: false → true` の状態復帰が確認される  
**意義**: テストの再現性・リセット可能性を保証する

---

## Implementation Checklist

- [x] testID naming convention established
- [x] GET /ping endpoint working
- [x] POST /perform with getState command
- [x] POST /perform with tap command
- [x] describedState mechanism
- [x] Phase A (Network) verification
- [x] Phase B (State Change) verification
- [x] Phase B-5 (Bidirectional Recovery) verification
- [x] setProperty command (getState/tap/setProperty/setEnabled 統一 I/F、5キー describedState)
- [x] tap semantics finalized (S2: guard isEnabled / isEnabled=false / title="Logged In"、5キー固定維持)
- [x] 全コマンド共通 Response schema 明文化（describedState 5キー固定）
- [x] Integration with CI/CD via pytest (STEP 1)

