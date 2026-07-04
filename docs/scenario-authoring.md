# シナリオ・オーサリングガイド

宣言的 UI シナリオ（`ui_runScenario`）を JSON で記述するためのリファレンスドキュメント。

## シナリオとは

UI テストシナリオは、複数のステップを**宣言的に記述**し、各ステップの後の UI 状態を`expect`（期待値）で検証する仕様です。シナリオの実行は MCP の `ui_runScenario` ツール経由で自動化され、各ステップの pass/fail が構造化データで返されます。

```json
{
  "name": "counter-flow",
  "steps": [
    {
      "action": "getState",
      "testID": "scene.demo.counter",
      "expect": { "count": 0 }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 1 }
    }
  ]
}
```

## トップレベルスキーマ

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `$schema` | string | 否 | JSON Schema 参照（例: `scenario.schema.json`） |
| `name` | string | **是** | シナリオ名（例: `counter-flow`, `login-flow`） |
| `steps` | array | **是** | 実行ステップの配列。先頭から順に実行される |

## ステップスキーマ

各ステップは以下のキーを持つオブジェクト：

| キー | 型 | 必須 | 説明 |
|---|---|---|---|
| `action` | string | **是** | 実行コマンド（列挙値） |
| `testID` | string | **是** | 対象コンポーネントの testID |
| `parameters` | object | 否 | コマンドパラメータ。コマンドにより形式が異なる |
| `expect` | object | 否 | 実行後の assert キー・期待値。複数キーを同時に検証可 |

## action（コマンド）カタログ

### ユニバーサルコマンド（すべてのコンポーネントで有効）

#### `getState`
コンポーネントの現在の描述状態（describedState）を取得します。副作用なし。

```json
{
  "action": "getState",
  "testID": "scene.demo.counter",
  "expect": { "count": 0, "isEnabled": true }
}
```

**parameters**: なし

---

#### `setProperty`
コンポーネントのプロパティを変更します。

```json
{
  "action": "setProperty",
  "testID": "scene.demo.counter",
  "parameters": { "key": "isEnabled", "value": false },
  "expect": { "isEnabled": false }
}
```

**parameters** 形式（必須）:
```json
{
  "key": "プロパティ名（文字列）",
  "value": "任意の値（number / boolean / string など）"
}
```

---

### コンポーネント固有コマンド

#### `tap`
ボタンなど、タップ可能なコンポーネントをタップします。

```json
{
  "action": "tap",
  "testID": "scene.auth.loginButton",
  "expect": { "title": "Logged In" }
}
```

**parameters**: なし

---

#### `increment` / `decrement`
数値カウンターを増加・減少させます（Counter など）。

```json
{
  "action": "increment",
  "testID": "scene.demo.counter",
  "expect": { "count": 1 }
}
```

**parameters**: なし

---

#### `reset`
コンポーネント（Counter など）を初期状態にリセットします。

```json
{
  "action": "reset",
  "testID": "scene.demo.counter",
  "expect": { "count": 0 }
}
```

**parameters**: なし

---

#### `toggle`
On/Off スイッチのトグル状態を反転します。

```json
{
  "action": "toggle",
  "testID": "scene.demo.switch",
  "expect": { "isOn": true }
}
```

**parameters**: なし

---

#### `clear`
テキスト入力フィールドなどをクリアします。

```json
{
  "action": "clear",
  "testID": "scene.form.nameInput",
  "expect": { "text": "" }
}
```

**parameters**: なし

---

#### `setEnabled`
コンポーネントの有効/無効を直接指定します。注: `setProperty { key: "isEnabled", value: bool }` との二重表記を避けるため、可能な限り `setProperty` の使用を推奨。

```json
{
  "action": "setEnabled",
  "testID": "scene.auth.loginButton",
  "parameters": false,
  "expect": { "isEnabled": false }
}
```

**parameters**: boolean（true / false）

---

## expect（アサーション）キーカタログ

### 固定（汎用）キー

以下の5キーはほぼすべてのコンポーネントで使用可能：

| キー | 型 | 説明 |
|---|---|---|
| `isEnabled` | boolean | コンポーネントが有効か |
| `title` | string | ボタンのテキストなどの表示文字列 |
| `isHidden` | boolean | コンポーネントが非表示か |
| `alpha` | number | 透明度（0.0 ～ 1.0） |
| `backgroundColor` | string | 背景色（色名または16進数カラーコード） |

```json
{
  "expect": {
    "isEnabled": true,
    "title": "Submit",
    "isHidden": false,
    "alpha": 1,
    "backgroundColor": "systemBlue"
  }
}
```

### コンポーネント固有キー

各コンポーネントはカスタム描述状態を持ち、固定キーに加えて任意キーで検証可能：

| コンポーネント | キー例 | 型 | 説明 |
|---|---|---|---|
| Counter | `count` | number | 現在のカウント値 |
| OnOffSwitch | `isOn` | boolean | オン/オフ状態 |
| TextInput | `text` | string | 入力テキスト |
| Slider | `value` | number | スライダー値 |
| Label | `label` | string | ラベルテキスト |

```json
{
  "expect": {
    "count": 5,      // Counter 固有
    "isEnabled": true // 汎用
  }
}
```

複数キーは AND 条件で突合：すべてのキーが期待値と一致して初めて pass。

---

## 完全な実装例

### counter-flow.json（Counter UI のテスト）

```json
{
  "$schema": "scenario.schema.json",
  "name": "counter-flow",
  "steps": [
    {
      "action": "getState",
      "testID": "scene.demo.counter",
      "expect": { "count": 0, "isEnabled": true }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 1, "isEnabled": true }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 2 }
    },
    {
      "action": "setProperty",
      "testID": "scene.demo.counter",
      "parameters": { "key": "isEnabled", "value": false },
      "expect": { "isEnabled": false }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 2, "isEnabled": false }
    }
  ]
}
```

このシナリオは以下を検証：
1. カウンターの初期状態は count=0 で有効
2. increment で count=1 に増加
3. もう一度 increment で count=2 に増加
4. setProperty で isEnabled=false に変更
5. 無効化されたコンポーネントに increment を送っても count は変わらない（=count=2 のままであることを確認）

---

### login-flow.json（ボタン状態遷移のテスト）

```json
{
  "$schema": "scenario.schema.json",
  "name": "login-flow",
  "steps": [
    {
      "action": "getState",
      "testID": "scene.auth.loginButton",
      "expect": {
        "isEnabled": true,
        "title": "Log In",
        "isHidden": false,
        "alpha": 1,
        "backgroundColor": "systemBlue"
      }
    },
    {
      "action": "tap",
      "testID": "scene.auth.loginButton",
      "expect": { "isEnabled": false, "title": "Logged In" }
    },
    {
      "action": "setProperty",
      "testID": "scene.auth.loginButton",
      "parameters": { "key": "isEnabled", "value": true },
      "expect": { "isEnabled": true, "title": "Logged In" }
    }
  ]
}
```

このシナリオは以下を検証：
1. ログインボタンの初期状態（有効・テキスト「Log In」・表示・不透明・青色背景）
2. tap でボタンが無効化され、テキストが「Logged In」に変わる
3. setProperty で再度有効化される

---

## オーサリングのコツ・落とし穴

### 1. 無効化後のコマンド実行は検証が必要

コンポーネントが無効化（`isEnabled: false`）された後も、コマンドは「送信される」ものの、状態変化が起きない可能性があります。このことを明示的に expect で検証しましょう：

```json
{
  "action": "setProperty",
  "testID": "scene.demo.counter",
  "parameters": { "key": "isEnabled", "value": false },
  "expect": { "isEnabled": false }
},
{
  "action": "increment",
  "testID": "scene.demo.counter",
  "expect": { "count": 0 }  // 増えないことを確認
}
```

### 2. expect は省略可

不要な検証を省略できます：

```json
{
  "action": "getState",
  "testID": "scene.demo.counter"
  // expect なし = 単に状態を取得するだけ
}
```

### 3. parameters の形式はコマンドごとに異なる

- `setProperty`: 必ず `{ "key": string, "value": any }` 形式
- `setEnabled`: boolean をそのまま渡す（`parameters: false`）
- その他コマンド: 通常省略

### 4. testID の正確さ

testID はコンポーネント側で設定された値と**完全に一致**する必要があります。タイポや部分一致は動作しません。

### 5. 色文字列の記法

`backgroundColor` は以下の形式で指定：
- 色名: `"systemBlue"`, `"systemRed"`, `"white"`, `"black"` など
- 16進数: `"#FF0000"`（大文字でも小文字でも可）
- RGB: コンポーネントの実装に依存（通常は色名推奨）

---

## JSON Schema 検証

すべてのシナリオは `Example/scenarios/scenario.schema.json` に照らして検証できます。IDE や JSON バリデータを使用して、before-commit に有効性を確認してください。

---

## 関連ドキュメント

- **IPC プロトコル詳細**: `docs/ipc-protocol.md` §4「/perform コマンドリファレンス」
- **設計仕様**: `docs/design.md` §E2「宣言的シナリオ（Scenario）の実装」
- **サンプルシナリオ**: `Example/scenarios/`（counter-flow.json, login-flow.json）
