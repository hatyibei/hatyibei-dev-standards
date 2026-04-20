# AGENTS.md

> Claude Code が書く。Codex が検査する。異なるバイアスの交差検証。

## Project structure

```
core/              — skills 11, commands 4, agent 1, hooks 3, rules 1 (不可侵)
extended/          — 参照専用 skills 1, commands 5, agent 1 (不可侵)
archive/           — 未使用定義の退避 (633 files, 不可侵)
agent/             — personality (Vane) + self-improvement loop
tools/             — lib/search/curation/personality shell utilities
skills/_generated/ — Opus 生成候補 (未検証、PR マージは P0 ブロック)
plans/             — PlanMode 実装計画アーカイブ
cron/              — 定期実行ジョブ集約
docs/adr/          — ADR-001〜012
```

## Coding standards

- Conventional Commits: `type(scope): description`
- ファイル命名: lowercase with hyphens
- relative imports 優先
- エラーハンドリングはシステム境界のみ
- 早期抽象化禁止 (YAGNI)
- `--no-verify` / `--no-gpg-sign` 禁止

## Testing

- TDD: RED → GREEN → REFACTOR
- テストなしの機能追加は P0 違反

## Review guidelines

### P0 — Block（1つでも該当すれば request changes）

- `--no-verify` または `--no-gpg-sign` の使用痕跡
- 認証情報のハードコード（API キー、シークレット、パスワード、`.env` のコミット）
- `NEXT_PUBLIC_` 環境変数にサーバーシークレットが含まれている
- テストなしの機能追加
- 認証が必要な API ルートの保護漏れ
- Stripe Webhook 署名検証の欠落
- XSS（`dangerouslySetInnerHTML`、未サニタイズの DOM 挿入）
- SQL / コマンド / プロンプトインジェクション
- `console.log` に個人情報・認証情報を出力
- ビルドが通らない変更
- `skills/_generated/**` に配置された未検証スキルの `core/` / `extended/` への直接取り込み（手動 `promote.sh` を経ずに）

### P1 — Flag（指摘して修正を求める）

- `console.log` / `console.debug` / `console.info` の残留
- Conventional Commits 形式でないコミットメッセージ
- 1 PR に複数の論理的変更が混在（1PR≠1問題）
- linter / formatter 設定の不要な緩和
- `any` 型の使用・型アサーションの乱用
- 外部 API 呼び出しのエラーハンドリング欠落
- テストカバレッジの著しい低下

### P2 — Suggest（改善提案のみ）

- `TODO` / `FIXME` コメントの残存
- diff が 500 行を超えている（PR の分割を提案）
- 命名規則の不統一
- デッドコード・不要なコメント
- インポート順序の乱れ

## Behavioral constraints

- PR の diff のみをレビューする。既存コードへの改善提案はしない
- 日本語でコメントする
- 修正提案にはコード例を含める
- P0 → request changes、P1 のみ → approve with comments、P2 のみ → approve
- セキュリティ指摘は該当コード行を引用する
- false positive を避けるため周辺コードで文脈を確認してから報告する
