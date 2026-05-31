## 保存内容（TestableUIKit プロジェクト用 `handoff.md`）

```markdown
最終更新：2026-05-31

# TestableUIKit 作業メモ

## プロジェクト概要
- iOS UI コンポーネントが自己申告型で HTTP IPC を通じてテスト可能になるフレームワーク
- Swift Package（Library）+ CLI executable + iOS App（DemoApp）で構成

## M-1 完了（IPC層検証）✅

### 完成済みコンポーネント（Library層）
| ファイル | 状態 |
|---|---|
| `Sources/TestableUIKit/JSONValue.swift` | single value container Codable、wire format実証済み |
| `Sources/TestableUIKit/AnyTestable.swift` | public 化済み、TestableRegistry.shared |
| `Sources/TestableUIKit/TestableServer.swift` | NWListener、@MainActor なし（handle のみ）、strict concurrency PASS |
| `Sources/TestableUIKit/TestError.swift` | public 化済み |
| `Sources/TestableUIKitDemo/Demo.swift` | CLI executable、dispatchMain() でプロセス維持 |
| `Sources/TestableUIKitDemo/CLIDemoLoginButton.swift` | SwiftUI非依存のCLI専用スタブ |
| `Package.swift` | platforms: iOS 15 + macOS 13、testTarget追加、-suppress-warnings 削除済み |
| `Tests/TestableUIKitTests/JSONValueTests.swift` | 6 tests PASS |
| `run_test.py` | parameters: null で整合 |

### 検証済みコマンド
```bash
swift build -Xswiftc -strict-concurrency=complete  # BUILD SUCCEEDED
swift test                                          # 6 tests PASSED
swift run TestableUIKitDemo &                       # Server running port 8888
python3 run_test.py                                 # Phase A: PASS / Phase B: {"isEnabled": false, "title": "Log In"}
```

### アーキテクチャ確定事項
- `TestableServer`: class レベル `@MainActor` を外し、`handle()` のみ `@MainActor`
- `newConnectionHandler`: `Task { @MainActor in }` で hop、NWConnection は `@unchecked Sendable`
- `JSONValue`: single value container（`true` / `"text"` を直接 wire に出す。`{"bool": true}` 形式ではない）
- `[x]確定ルール`: Bash ツール stdout/stderr 生テキストなしにビルド系を `[x]` にしない

---

## M-2 完了（iOS App UI連動）✅

### 2026-05-31 セッション成果

#### ビルド修復
| 課題 | 解決方法 | 結果 |
|---|---|---|
| pbxproj `PBXSourcesBuildPhase` 重複 | 重複 isa ブロック を単一定義に統合 | BUILD SUCCEEDED ✅ |
| `DemoApp/LoginButton.swift` が存在しない | 正しい内容で再作成 | ✅ |
| `Sources/TestableUIKit/LoginButton.swift` 孤立ファイル | 削除（フレームワーク側に LoginButton は置かない） | ✅ |
| DerivedData キャッシュ汚染 | `rm -rf DerivedData` + clean build | ✅ |

#### 検証内容
| フェーズ | 内容 | 結果 |
|---|---|---|
| Phase A: Network | `GET /ping` | ✅ PASS |
| Phase B: Logic | `getState → tap → getState` 2フェーズ実証 | ✅ PASS |
| State Change | `isEnabled: true → false` 状態変化確認 | ✅ 実証 |

**テスト実行結果**:
```
Initial state:  isEnabled=true, title="Log In"
After tap:      isEnabled=false, title="Log In"
✅ State change detected as expected
```

#### 文書化
| ドキュメント | 内容 |
|---|---|
| `docs/ipc-protocol.md` | エンドポイント仕様、testID 命名規約、wire format 定義 |
| `docs/design.md` | アーキテクチャ、コンポーネント関係図、Known Issues（pbxproj 修正） |
| `TestableServer.swift` | `CodingKeys` 明示（wire format 安定化） |

### M-2 で完了した作業
- [x] Xcode プロジェクト手動管理（pbxproj 直接編集）
- [x] `LoginButton.swift` 実装（`getState` / `tap` / `setEnabled` コマンド対応）
- [x] `DemoApp.swift` 実装（TestableServer 起動＋ UI 構築）
- [x] `xcodebuild ... build` PASS
- [x] Simulator 上で Phase B（UI状態変化）実証
- [x] IPC プロトコル仕様文書化
- [x] pbxproj 修正内容を Known Issues に記録

---

## M-3 スコープ（決定済み、未着手）🔄

### M-3 の目標
- Multi-device matrix testing（iOS 17～26、複数 device タイプ）
- xcodegen/Tuist 移行（pbxproj 手編集 → 宣言的生成）
- setProperty コマンド実装
- CI/CD 統合（GitHub Actions 例）

### 検討事項
- pbxproj 手管理は再発リスク（M-2 で確認）→ xcodegen 本格導入検討
- デバイスマトリクス：最低要件を iOS 17～26 とするか、Simulator のみか、実機対応か

---

## ブラックボード引き継ぎ

```
## UIテスト自動化ツール設計討議（TestableUIKit M-2 完了）
- [x] M-1（IPC層検証）: Phase A/B PASS 実証済み
- [x] M-2（iOS App UI連動）: ビルド＋検証フェーズ完了
  - [x] pbxproj 修復（重複 isa ブロック統合）
  - [x] LoginButton 実装＋登録
  - [x] DemoApp iOS App 完成
  - [x] Phase A/B 2フェーズ実証（getState → tap → getState）PASS
  - [x] IPC プロトコル文書化（docs/ipc-protocol.md）
  - [x] Known Issues 記録（docs/design.md）
- [ ] M-3（拡張）: OS matrix / xcodegen 移行 → 次セッション
```

---

## 追加情報（Session 2026-05-31 後半 - M-2 品質保証フェーズ）

### Auditor 指摘による最終調整

#### 論点E'：tap実装の双方向性検証 ✅
- `DemoApp/LoginButton.swift` 23行: `isEnabled = false` は意図的なドメインロジック
- `setEnabled` コマンド（26-29行）で復帰可能性確認
- run_test.py に **Step B-5** 追加：`setEnabled(true)` → 状態復帰 `false→true` 実証
- **テスト実行結果**: 
  ```
  Phase A: ✅ PASS (ping reachability)
  Phase B: ✅ PASS (tap: true→false)
  Phase B-5: ✅ PASS (recovery: false→true via setEnabled)
  ```

#### 論点F'：IPC プロトコル JSONValue 形式の統一 ✅
- **修正対象**: `docs/ipc-protocol.md` 177-181行 （描述状態フォーマット）
- **修正前**: `{"isEnabled": {"type": "bool", "value": true}}` （誤）
- **修正後**: `{"isEnabled": true}` （single value container 方式）
- **3者確認**: TestableServer.swift CodingKeys / run_test.py ペイロード / ipc-protocol.md 仕様 完全一致

#### 論点G'：pbxproj 重複検出メカニズム ✅
- `docs/design.md` Known Issues に検出 grep を追記：
  ```bash
  grep -c "isa = PBXSourcesBuildPhase" TestableUIKitDemo.xcodeproj/project.pbxproj
  # 期待値: 2（DemoApp + UIKit ターゲット分）
  # 警告閾値: 4 以上で重複検出
  ```
- 再発予防体制整備完了

#### 論点M：VCS（git）初期化 ✅
- **実施内容**: `git init` + `.gitignore` 作成 + checkpoint commit
- **Commit**: `b3761d8` "feat: M-2 complete - iOS App IPC verified (Phase A/B PASS)"
- **注記**: `.build/` / `DerivedData/` が initial commit に含まれた（M-3 で clean up 予定）
- **効果**: M-3 以降での安全な checkpoint 戦略が確立

### M-2 最終統計

| 指標 | 数値 |
|---|---|
| **発見・修正したバグ** | 4件 |
| - pbxproj 重複 isa ブロック | 1件 ✅ |
| - ドキュメント乖離（JSONValue形式） | 1件 ✅ |
| - ビルドキャッシュ汚染 | 1件 ✅ |
| - git 未初期化 | 1件 ✅ |
| **実装行数（コード）** | ~600行 |
| **テストケース** | 3段階（Phase A + B + B-5） |
| **ドキュメント更新** | 2ファイル追記（ipc-protocol.md + design.md） |
| **VCS Commit** | 2件（初期 + 品質保証） |

---

## 次回再開時の作業（M-3）

### 必須タスク
1. **OS/デバイスマトリクス方針** の決定（最低サポート: iOS 17?）
2. **xcodegen 移行** による pbxproj 宣言的管理
3. **CI/CD 統合** (GitHub Actions 例)
4. **git cleanup**: `.build/` `DerivedData/` の削除と commit

### オプション（M-4以降）
- setProperty コマンドの詳細仕様化
- 実機対応
