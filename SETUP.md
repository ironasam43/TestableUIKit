# TestableUIKit Demo App セットアップ手順

iOS Simulator 上で TestableUIKit を実行するための手順書です。

## 前提条件

- Xcode 14.0 以上
- iOS 14 以上の Simulator
- Python 3.8 以上（テストランナー用）

## ステップ 1：iOS App プロジェクト作成

### 1-1. Xcode を起動し、新規プロジェクト作成

```
Xcode > File > New > Project...
```

### 1-2. プロジェクトテンプレート選択

- **Platform**: iOS
- **Template**: App

### 1-3. プロジェクト設定

| 項目 | 値 |
|---|---|
| Product Name | `TestableUIKitDemo` |
| Team | （自分の Team を選択） |
| Organization Identifier | `com.example` |
| Interface | SwiftUI |
| Language | Swift |

### 1-4. プロジェクト保存先

```
/Users/koba-p/Documents/Dev/projects/TestableUIKit/
```

✅ プロジェクトが作成されました。Xcode が開きます。

---

## ステップ 2：TestableUIKit ライブラリを依存に追加

### 2-1. Package 依存を追加

```
Project (TestableUIKitDemo) > Package Dependencies > +
```

### 2-2. ローカルパス指定

```
Add Local...
```

ディレクトリを選択：
```
/Users/koba-p/Documents/Dev/projects/TestableUIKit
```

### 2-3. バージョン確認

- Branch: `main` （または最新）
- 依存を追加

✅ TestableUIKit が Linked Frameworks に追加されました。

---

## ステップ 3：ファイル追加

### 3-1. DemoApp.swift を追加

1. Xcode で `File > New > File...` を選択
2. `Swift File` テンプレートを選択
3. ファイル名：`DemoApp.swift`
4. Save 先：プロジェクト直下
5. 以下のコードを全て貼り付け：

```swift
// === ここから ===
// DemoApp-iOS-template.swift の内容を全てコピペ
// === ここまで ===
```

参考ファイル：
```
../DemoApp-iOS-template.swift
```

### 3-2. LoginButton.swift を追加

同様に `LoginButton.swift` を作成：

```swift
// === ここから ===
// LoginButton-iOS-template.swift の内容を全てコピペ
// === ここまで ===
```

参考ファイル：
```
../LoginButton-iOS-template.swift
```

✅ 両ファイルが Xcode プロジェクトに追加されました。

---

## ステップ 4：ビルド設定確認

### 4-1. Build Settings を確認

```
Project (TestableUIKitDemo) > Build Settings
```

| キー | 値 |
|---|---|
| iOS Deployment Target | 14.0 以上 |
| Architectures | arm64 (Simulator は x86_64) |

### 4-2. Signing & Capabilities を設定（必要に応じて）

```
Project > Signing & Capabilities > Team を設定
```

✅ ビルド設定が完了しました。

---

## ステップ 5：Simulator を起動

### 5-1. Simulator デバイス選択

```
Xcode > Product > Destination > [お好みの iPhone] > Simulator
```

例：
- `iPhone 15 Pro (17.0)`
- `iPhone 14 (16.0)`

### 5-2. Simulator を起動

```
Xcode > Product > Run
または Command + R
```

**初回起動時：**
- Simulator が起動します（1-2 分待機）
- DemoApp が Simulator 上に表示されます

✅ DemoApp が Simulator で起動し、「Testable UIKit Demo」画面が表示されます。

---

## ステップ 6：テスト実行

### 6-1. Simulator でアプリが起動していることを確認

画面に以下が表示される：
- `Testable UIKit Demo` （タイトル）
- `Log In` ボタン（ブルー色）
- `Server running on http://localhost:8888`

### 6-2. コンソールでサーバー起動確認

Xcode の Debug Console に以下が表示される：

```
[SERVER] Started on http://localhost:8888
```

### 6-3. Python テストランナーを実行

別ターミナルを開き、プロジェクトディレクトリで：

```bash
cd /Users/koba-p/Documents/Dev/projects/TestableUIKit
python3 run_test.py
```

### 6-4. テスト結果確認

#### Phase A（ネットワーク経路確認）

```
[PHASE A] Network Path Verification
...
✅ [PASS] Server is reachable
   Response: {"status": "ok"}
```

#### Phase B（ロジック検証）

```
[PHASE B] Logic Verification - Tap LoginButton
...
✅ [PASS] Tap command successful
   Response: {
     "isEnabled": true,
     "title": "Log In"
   }
```

✅ **All tests passed!** が表示されれば完成。

---

## トラブルシューティング

### エラー：`No module named 'requests'`

```bash
pip3 install requests
```

### エラー：`curl: command not found`

macOS にはデフォルトで curl が含まれています。別の方法でテスト：

```bash
# curl の代わりに Python requests を使用
# run_test.py を手動修正して requests 使用に変更
```

### エラー：`Server not reachable`

Simulator が localhost:8888 にアクセスできない場合：

1. **Simulator を再起動**：
   ```
   Xcode > Device > Erase All Content and Settings...
   ```

2. **ファイアウォール確認**：
   ```
   System Preferences > Security & Privacy > Firewall
   ```

3. **Xcode 再起動**

### エラー：`isEnabled が false`

ボタンが disabled 状態。DemoApp.swift の LoginButton 初期化を確認：

```swift
button.isEnabled = true  // 追加
```

---

## 次のステップ

垂直スライスの検証が完了しました。以下は次フェーズです：

- Contract 定義の追加（validators）
- スクリーンショット + 変化分析
- AI テスト生成の統合

---

**質問や問題がある場合は、Auditor に報告してください。**
