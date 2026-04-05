# Core Rules

ECC guardrails と実際の開発実績に基づく統合ルール。

## コミット規約

- **形式**: Conventional Commits — `type(scope): description`
- **prefix**: feat, fix, test, docs, ci, chore, perf, refactor, ux, design
- **1コミット = 1つの論理的変更**
- `--no-verify` 禁止（hook `block-no-verify.sh` で強制）
- `--amend` は明示的に指示された場合のみ
- Co-Authored-By ヘッダーでAI協業を明記

## コードスタイル

- **ファイル命名**: lowercase with hyphens（例: `session-start.js`）
- **インポート**: relative imports を優先
- **関数**: `function` keyword を arrow functions より優先（top-level）
- **エラーハンドリング**: システム境界（ユーザー入力、外部API）でのみバリデーション
- **抽象化**: 3回似たコードがあっても早期抽象化より直接記述 (YAGNI)

## レビュー

- 2段階: 仕様準拠 → コード品質
- PR全体のdiffをレビュー（最新コミットだけでなく）
- 1 PR = 1 問題
- 信頼度スコア付きレビュー推奨（`/loop code-review` で自動化可能）

## セキュリティ

- OWASP Top 10 を常に意識
- 認証情報をコミットしない
- Stripe Webhook署名検証は必須
- プロンプトインジェクション対策（Vertex AI連携時）
- `fix(security):` prefix で監査修正を追跡

## 品質ゲート（必須）

全てのコード変更で以下を通過:
1. 既存テストが全てパス
2. セキュリティチェック（認証情報の混入なし）
3. ビルド成功
4. 変更の動作確認

## Hook結線

```
settings.json:
├── PreToolUse
│   ├── Bash       → core/hooks/block-no-verify.sh  (hard fail)
│   └── Edit|Write → core/hooks/config-protection.sh (soft warn)
└── PostToolUse
    └── Edit       → core/hooks/console-warn.sh      (soft warn)
```

## アーキテクチャ (ECC-derived)

- `hybrid` モジュール構成を維持
- テストレイアウト: `separate`（テストファイルはソースと分離）
- Markdown/Agent ファイル: YAML frontmatter 必須（`name`, `description`）
