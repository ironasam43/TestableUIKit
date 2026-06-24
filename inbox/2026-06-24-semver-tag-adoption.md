# semver タグ運用の導入と初期 v0.x タグ起票

- **発生元**: HQ（Dev/ タブ）／2026-06-24
- **依頼種別**: 本線ロードマップ（能力/駆動論マップ wrap-up ステップ4）

## 背景

TestableUIKit は SPM ライブラリ（`Package.swift` で `.library(name: "TestableUIKit")` を公開、remote = `github.com/ironasam43/TestableUIKit`）だが、**semver タグが実測 0 件**。タグが無いと:

- 利用側（DeeperAI 等）が `.package(url:, from: "x.y.z")` / `exact:` でバージョン固定できず、ブランチ／コミット pin に頼らざるを得ない
- 破壊的変更と後方互換変更の区別が利用側に伝わらない
- リリース履歴が GitHub Releases に乗らない

§6 #3（B=Swift MCP 化方針）が `512b9f8` で最終確定し、本線の次の一手として「v0.x semver タグ運用の第一歩」を着手する段階。

## 修正対象・要求内容

1. **現状の公開 API 安定度を確認** — まだ pre-1.0（破壊的変更を許容する段階）なら `v0.x` 系で開始する。
2. **初期 semver タグを 1 本切る** — 現在の `main` HEAD に対し妥当な初期バージョン（例 `v0.1.0`）を annotated tag で付与し、push する。
   - バージョン番号の選定（`v0.1.0` か、既に実用域なら `v0.x` の妥当値か）は当該タブの判断に委ねる。
3. **タグ運用ルールを明文化** — `projects/TestableUIKit/docs/`（handoff か README か design）に「いつ・どの粒度で semver タグを切るか（pre-1.0 の MINOR/PATCH 運用方針）」を 1 節追記。
4. （任意）GitHub Releases 化は当該タブ判断。最低限タグ push までで可。

## 完了条件

- `git -C projects/TestableUIKit tag` が 1 件以上を返す（初期 v0.x タグが存在）
- そのタグが remote へ push 済み（`git ls-remote --tags origin` で確認可能）
- semver 運用方針が `docs/` のいずれかに明文化されている
- `docs/history.md` に対応を追記

## 検収

不要（完了条件を自己確認のうえ、この inbox ファイルを削除して終了）

## 補足

- HQ 側の関連コミット `512b9f8`（§6 #3 確定）は **push 未**。本対応に直接は依存しないが、本線の文脈として共有。
- バージョン番号・タグ粒度の最終判断は TestableUIKit タブに委譲する（HQ は方針起票のみ）。
