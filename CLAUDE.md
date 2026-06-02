# CLAUDE.md (TestableUIKit)

ルート共通設定は `../../CLAUDE.md` を参照してください。
現在の作業状況・TODO は `handoff.md` を参照してください。

## プロダクト概要

- **アプリ名**: TestableUIKit
- **概要**: iOS/macOS 向けの UIコンポーネント自己申告型テストフレームワーク。UI コンポーネントが `testID`・状態スナップショット・コマンド実行を自己申告し、HTTP ベースの IPC 経由で UI テストを自動化する
- **差別化**: Swift 型システムと AI を融合した、コンポーネント自己申告型テストフレームワーク
- **リポジトリ**: https://github.com/ironasam43/TestableUIKit

## 技術スタック

- **言語**: Swift（swift-tools-version 5.9）
- **対象 OS**: iOS 15.0+ / macOS 13.0+（Xcode プロジェクトは iOS 16.0+ デプロイ）
- **依存管理**: Swift Package Manager（外部依存なし）
- **テストランナー**: Python（`run_test.py`、Phase A/B）

## 構成要素

- **TestableUIKit**（ライブラリ）: コア実装
  - `JSONValue.swift` — JSON 値の型定義（Codable）
  - `AnyTestable.swift` — `@MainActor` / Actor protocol（`testID`・`describedState`・`perform`）
  - `TestableServer.swift` — Registry + HTTP handler（localhost:8888）
- **TestableUIKitDemo / DemoApp** — SwiftUI 参照実装（コンポーネント計装の例）
- **IPC**: HTTP over localhost:8888（クラウド・外部依存なし）
  - `GET /ping` — 疎通確認
  - `POST /perform` — コンポーネントへのコマンド実行

## ビルド・実行

- SPM: `swift build` / `swift test`
- Xcode: `TestableUIKitDemo.xcodeproj`（XcodeGen 管理。`project.yml` から生成）
- テスト自動化: `python3 run_test.py`

## ドキュメント

- 設計・アーキテクチャ: `docs/design.md`
- IPC プロトコル仕様: `docs/ipc-protocol.md`
- 変更履歴: `docs/history.md`
- Xcode セットアップ手順: `SETUP.md`

## 固有のコーディング規約

- ルート CLAUDE.md の共通規約に準拠
- 提案は日本語で返してください
- 大きな変更の前には必ず方針を確認してください
- ビルド確認は Human から明示的な指示があったときのみ実行する
