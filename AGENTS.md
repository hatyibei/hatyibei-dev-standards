# AGENTS.md — Codex Review Guidelines

> Claude Code が書く。Codex が検査する。異なるバイアスの交差検証。
> Codex Cloud のアカウント連携で動作。API Key 不要。

## Project structure

```
core/           — 実績ベースの開発標準（skills, commands, agents, hooks, rules）
extended/       — 参照専用のコマンド・エージェント
archive/        — 退避済み（未使用の定義群）
docs/adr/       — アーキテクチャ判断記録 (ADR-001〜009)
```

## Coding standards

- Conventional Commits 形式: `type(scope): description`
- prefix: feat, fix, test, docs, ci, chore, perf, refactor, ux, design
- ファイル命名: lowercase with hyphens
- relative imports を優先
- top-level 関数は `function` keyword（arrow functions より優先）
- エラーハンドリングはシステム境界でのみ（ユーザー入力、外部API）
- 早期抽象化禁止 (YAGNI)
- `--no-verify` / `--no-gpg-sign` 禁止
- `--amend` は明示的に指示された場合のみ

## Testing

- TDD: RED → GREEN → REFACTOR
- 既存テストは全てパスすること
- テストなしの機能追加は禁止（P0）

## Review guidelines

### P0 — Must fix（マージブロッカー。1つでも Request Changes）

- テストなしの機能追加
- `--no-verify` / `--no-gpg-sign` の痕跡
- 認証情報のハードコード（API キー、シークレット、パスワード、`.env` のコミット）
- 認証が必要な API ルートの保護漏れ
- Stripe Webhook 署名検証の欠落
- XSS（`dangerouslySetInnerHTML`、未サニタイズの DOM 挿入）
- SQL インジェクション / コマンドインジェクション
- プロンプトインジェクション（Vertex AI へのユーザー入力未検証）
- `console.log` に個人情報・認証情報を出力
- `git push --force` to main/master
- ビルドが通らない変更
- `NEXT_PUBLIC_` 環境変数にサーバーシークレットが含まれている

### P1 — Should fix（強く推奨）

- Conventional Commits 形式でないコミットメッセージ
- `console.log` / `console.debug` / `console.info` の残留（デバッグ用）
- 1 PR に複数の論理的変更が混在
- linter / formatter 設定の緩和（コードを修正する代わりに設定を弱めている）
- 外部 API 呼び出しのエラーハンドリング欠落
- 型安全性の低下（`any` の使用、型アサーションの乱用）
- テストカバレッジの著しい低下
- レスポンシブ対応の欠落（モバイル 375px で表示崩れ）
- Firestore セキュリティルールの不適切な変更
- レート制限の欠如（公開 API エンドポイント）
- 金額・通貨のクライアントサイド改ざん可能性

### P2 — Nice to have（改善提案）

- 命名規則の不統一
- 不要なコメントやデッドコード
- インポート順序の乱れ
- 重複コード（ただし3回未満なら許容）

## Security focus areas

レビュー時に特に注意するセキュリティ領域:

- **認証・認可**: Firebase Auth / NextAuth セッション検証、管理者エンドポイントの権限チェック、CORS 設定
- **Stripe**: Webhook 署名検証 (`stripe.webhooks.constructEvent`)、Price ID のサーバーサイドバリデーション
- **AI連携**: Vertex AI へのプロンプトインジェクション対策 (`validatePromptContent`)、安全設定（著名人・医療診断・ネガティブラベリング禁止）
- **シークレット**: クライアントサイドへのサーバーシークレット露出、`NEXT_PUBLIC_` prefix の誤用

## Behavioral constraints

- PR の差分のみをレビュー対象とする（既存コードの改善提案はしない）
- 日本語でコメントする
- 修正提案にはコード例を含める
- P0 がある場合のみ Request Changes、それ以外は Approve with comments
- セキュリティ関連の指摘は必ず該当コード行を引用する
- 推測ではなくコードの事実に基づいて指摘する
- false positive を減らすため、周辺コードを読んで文脈を確認してから報告する
