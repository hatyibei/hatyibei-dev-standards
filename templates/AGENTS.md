# AGENTS.md

> Claude Code が書く。Codex が検査する。

## Project structure

<!-- TODO -->

## Review guidelines

### P0 — Block（1つでも該当すれば request changes）

- `--no-verify` または `--no-gpg-sign` の使用痕跡
- 認証情報のハードコード（API キー、シークレット、パスワード、`.env` のコミット）
- `NEXT_PUBLIC_` 環境変数にサーバーシークレットが含まれている
- テストなしの機能追加
- 認証が必要な API ルートの保護漏れ
- XSS / SQL / コマンド / プロンプトインジェクション
- ビルドが通らない変更

### P1 — Flag（指摘して修正を求める）

- `console.log` / `console.debug` / `console.info` の残留
- Conventional Commits 形式でないコミットメッセージ
- 1 PR に複数の論理的変更が混在
- `any` 型の使用・型アサーションの乱用
- 外部 API 呼び出しのエラーハンドリング欠落

### P2 — Suggest（改善提案のみ）

- `TODO` / `FIXME` コメントの残存
- diff が 500 行を超えている（PR の分割を提案）
- 命名規則の不統一
- デッドコード

## Behavioral constraints

- PR の diff のみをレビューする
- 日本語でコメントする
- P0 → request changes、P1 のみ → approve with comments、P2 のみ → approve
