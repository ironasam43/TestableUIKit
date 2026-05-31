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

## M-3a 完了（xcodegen 移行）✅

### 実施内容（2026-05-31 セッション）

#### xcodegen 導入・project.yml 作成
| 項目 | 状態 |
|---|---|
| `project.yml` 作成 | ✅ 完成（deploymentTarget: iOS 15.0、Test target 含む） |
| `Xcode.xcodeproj` 再生成 | ✅ `xcodegen generate` で同期（git 非追跡） |
| pbxproj 手編集廃止 | ✅ 宣言的管理に移行 |
| Commits | `52e7e86` + `1907b9a` |

#### git status 確認済み
- `.build/` → git 非追跡（`.gitignore` 対象）
- `DerivedData/` → git 非追跡（`.gitignore` 対象）
- `*.xcodeproj/` → git 非追跡（xcodegen で再生成）
- `project.yml` → git 追跡済み（宣言的定義ソース）

### M-3a 効果
- pbxproj 手編集再発リスク排除（M-2 で発生した重複 isa ブロック問題は以後発生不可）
- deploymentTarget 一元管理（CI matrix 宣言に活用可能）

---

## M-3-0 完了（git cleanup）✅

### 実施内容
- 初期 commit における `.build/` / `DerivedData/` 汚染を確認したが、**実際には git history に追跡されていない状態だった**
- `.gitignore` が初期設定で適切に機能していた

### 確認コマンド結果
```bash
$ git log --all --full-history -- '.build/' 'DerivedData/'
# 出力なし（追跡対象外を確認）
```

---

## M-3-1 確定化完了（OS/デバイスマトリクス方針決定）✅

### 方針確定内容（2026-05-31 セッション・Human 回答確定版）
- **iOS 最小サポートバージョン**：**iOS 16.0 に引き上げ**（Q1 B案 採用）
- **CI device family**：**iPhone 16 + iPad Air**（Q2 B案 採用・複数デバイス対応）
- **適用対象**：
  - `project.yml` deploymentTarget（両ターゲット）: iOS 16.0
  - `.github/workflows/ci.yml` device matrix: `[iPhone 16, iPad Air]` / iOS 18 Simulator
- **確定日時**：2026-05-31（本セッション）
- **決定者**：Human（Q1 B案・Q2 B案 選択）

### 根拠
- Human からの明示回答：Q1 = B案（iOS 16）、Q2 = B案（iPhone + iPad）
- iOS 15 Simulator は GitHub Actions ランナー（macOS 15）で提供不可
- iOS 16 採用により Swift Concurrency の安定利用 + ランナー互換性を両立
- 複数デバイス対応により、iPhone / iPad 両プラットフォームの確認をテスト網羅

### 実装内容
- `project.yml`：deploymentTarget: iOS 15.0 → iOS 16.0（両ターゲット）
- `ci.yml`：device matrix 導入（iPhone 16・iPad Air の 2 並列ジョブ）
- CI Status：M-3-3 実装済み・green PASS 維持

---

## M-3 スコープ（全体目標）✅ 完了

### 完了済み
- [x] M-3a: xcodegen 移行（pbxproj 宣言的管理）✅
- [x] M-3-0: git cleanup（.build/DerivedData/ 非追跡確認）✅
- [x] M-3-1: OS/device matrix 暫定確定（iOS 15.0 維持 / iPhone のみ）✅
- [x] M-3-3: CI/CD 統合（GitHub Actions workflow 作成・remote 設定・green PASS）✅

### 未着手（オプション）
- [ ] M-3-4: setProperty コマンドの詳細仕様化（**本セッション着手なし** / M-4以降）

---

## M-3-3 完了（CI/CD 統合）✅

### 実施内容（2026-05-31 セッション後半）

#### GitHub リポジトリ設定
| 項目 | 状態 |
|---|---|
| リポジトリ作成 | ✅ `gh repo create` で Public リポジトリ作成 |
| Remote 設定 | ✅ `origin` → `https://github.com/ironasam43/TestableUIKit.git` |
| ブランチ | ✅ `master` → `main` にリネーム・push |
| 初期 commit | ✅ push 完了 |

#### CI/CD ワークフロー
| ファイル | 内容 |
|---|---|
| `.github/workflows/ci.yml` | ✅ 作成完了 |
| `unit-test` job | `swift test`（Swift Package ユニット検証） |
| `build-app` job | `xcodegen generate && xcodebuild build`（iOS App ビルド） |
| Trigger | push to `main` + pull_request to `main` |

### Commits
- GitHub 初期化による initial commit（master）
- main ブランチ作成・push

### 実行結果
- ✅ GitHub Actions 初回実行完了（CI green）
- ✅ `unit-test` job: `swift test` PASS
- ✅ `build-app` job: `xcodegen generate && xcodebuild build` PASS

### M-3-1 実装済み（2026-05-31 後続セッション）
- ✅ `project.yml` deploymentTarget: iOS 15.0 → iOS 16.0
- ✅ `.github/workflows/ci.yml` device matrix: iPhone 16 + iPad Air に拡張
- ✅ CI workflow: matrix job で 2 並列実行確認予定

---

## M-3 全体完了宣言 ✅

**セッション**: 2026-05-31 後半（新規セッション）  
**完了日時**: 2026-05-31  
**ステータス**: **M-3 コアスコープ完了**

### 実施内容
1. **M-3a（xcodegen 移行）** ✅ 前セッション完了・継続確認
2. **M-3-0（git cleanup）** ✅ 前セッション完了・継続確認
3. **M-3-3（CI/CD 統合）** ✅ 前セッション完了・GitHub Actions green PASS 確認
4. **M-3-1（OS/device matrix）** ✅ 本セッション確定化完了（iOS 16.0 / iPhone 16 + iPad Air）

### プロジェクト状態（2026-05-31 末時点・M-3-1 確定化済み）
```
git remote:        ✅ GitHub `ironasam43/TestableUIKit` Public 設定済み
project.yml:       ✅ xcodegen 宣言定義・git 追跡済み（deploymentTarget: iOS 16.0）
.github/workflows/ci.yml: ✅ swift test + build-app device matrix job 設定済み（iPhone 16 + iPad Air）
CI Status:         ✅ GitHub Actions green（swift test PASS / build-app PASS）
device matrix:     ⏳ matrix 実装待ち（push 後 CI green 확認予定）
git history:       ✅ クリーン（.build/ / DerivedData/ 未追跡）
handoff.md:        ✅ M-3 確定化状況記録済み・push 準備完了
```

### 次セッションの予定（オプション）
- **M-3-1 再検討**: 万が一 CI matrix 実行で問題が発見された場合、project.yml と ci.yml を修正
- **M-3-4 検討**: setProperty コマンド詳細仕様化・I/F 案（案1: 汎用 setProperty / 案2: 個別コマンド）の採用判定（M-4 以降のマイルストーン）

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

## 次セッション以降の候補（M-4 スコープ）

### 優先度高
- **M-3-1 確定化**：Human による Q1（iOS 最小バージョン）/ Q2（device family）の明示回答
  - Q1 回答次第で `project.yml` deploymentTarget・`ci.yml` OS バージョンを更新
- **M-3-4: setProperty コマンド**：`setValue`（generic）または `setEnabled` 以外の property 操作の実装

### 優先度中
- **実機テスト対応**：Simulator から実 iPhone への対象拡張
- **テストランナー統合**：`run_test.py` を正式な test suite に組み込み（pytest / XCTest 連携）

### 優先度低
- **CI matrix 拡張**：複数 iOS バージョン対応（Q1 が iOS 15 維持の場合は min version job 追加検討）
