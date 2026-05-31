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
```json
{
  "<fieldName1>": <value1>,
  "<fieldName2>": <value2>
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

**実装例**:
```swift
case "getState":
  return describedState
```

---

### tap

**目的**: ボタン等のタップアクション実行  
**パラメータ**: なし

**実装例** (LoginButton):
```swift
case "tap":
  isEnabled = false  // tap 後の状態変化
  return describedState
```

---

### setProperty

**目的**: プロパティ値を設定  
**パラメータ**: `{"propertyName": "string", "value": <value>}`

**実装例**:
```swift
case "setProperty":
  if let dict = parameters.dictionaryValue,
     let propName = dict["propertyName"]?.stringValue,
     let value = dict["value"] {
    // 該当プロパティを value に設定
  }
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
    "propertyName": "isEnabled",
    "value": true
  }
}
```

---

## describedState Format

各 `AnyTestable` 実装は `describedState` を返す際、以下の構造を使用：

```swift
var describedState: [String: JSONValue] {
  [
    "isEnabled": .bool(isEnabled),
    "title": .string(title)
  ]
}
```

レスポンスは以下の形式で JSON 化（single value container 方式）：

```json
{
  "isEnabled": true,
  "title": "Log In"
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
1. `/perform` で `getState` コマンド → 初期状態を取得（例: `isEnabled: true`）
2. `/perform` で `tap` コマンド → 状態変化を実行（例: `isEnabled → false`）
3. `/perform` で `getState` コマンド → 最終状態を取得し、変化を確認

**期待**: `isEnabled: true → false` の状態遷移が確認される

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
- [ ] setProperty command (future)
- [ ] Integration with CI/CD test frameworks (future)

