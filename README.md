# hatyibei-dev-standards

hatyibei の AI 駆動開発標準 - Claude Code ハーネス土台

## 概要

4つの先進的リポジトリから抽出したベストプラクティスを統合した、個人開発標準のアーキテクチャ判断記録 (ADR) とハーネス設定。

### ソースリポジトリ

| リポジトリ | 抽出した知見 |
|-----------|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | エージェント・スキル・フックの包括的フレームワーク |
| [claude-mem](https://github.com/thedotmack/claude-mem) | 永続メモリと知識管理の設計思想 |
| [aidlc-workflows](https://github.com/awslabs/aidlc-workflows) | AI駆動開発ライフサイクル、適応的深度 |
| [superpowers](https://github.com/obra/superpowers) | 構造化ワークフロー、TDD、サブエージェント駆動開発 |

## ADR 一覧

| ID | タイトル | 概要 |
|----|---------|------|
| [ADR-001](docs/adr/ADR-001-ai-driven-development-lifecycle.md) | AI駆動開発ライフサイクル | INCEPTION → CONSTRUCTION → OPERATIONS の3フェーズモデル |
| [ADR-002](docs/adr/ADR-002-test-driven-development.md) | テスト駆動開発 | RED-GREEN-REFACTOR サイクルの強制 |
| [ADR-003](docs/adr/ADR-003-persistent-memory-system.md) | 永続メモリシステム | セッション間の知識保持 |
| [ADR-004](docs/adr/ADR-004-skill-based-architecture.md) | スキルベースアーキテクチャ | 再利用可能なスキル定義 |
| [ADR-005](docs/adr/ADR-005-hook-driven-automation.md) | フック駆動自動化 | ライフサイクルフックによる自動化 |
| [ADR-006](docs/adr/ADR-006-subagent-driven-development.md) | サブエージェント駆動開発 | タスク委譲と並列実行 |
| [ADR-007](docs/adr/ADR-007-code-review-protocol.md) | コードレビュープロトコル | 2段階レビュー (仕様準拠 → 品質) |
| [ADR-008](docs/adr/ADR-008-quality-gates-and-adaptive-depth.md) | 品質ゲートと適応的深度 | タスク複雑さに応じたプロセス調整 |

## 使い方

1. このリポジトリをクローン
2. `CLAUDE.md` をプロジェクトのルートにコピーまたはシンボリックリンク
3. 必要に応じて `skills/`, `hooks/`, `agents/` を自プロジェクトに組み込み
4. ADR を参照して判断根拠を確認

## 構造

```
├── CLAUDE.md              # Claude Code ハーネス設定 (メイン)
├── docs/adr/              # アーキテクチャ判断記録
├── skills/                # 再利用可能なスキル定義
├── hooks/                 # ライフサイクルフック
├── agents/                # サブエージェント定義
├── commands/              # スラッシュコマンド
├── rules/                 # 言語・フレームワーク別ルール
└── configs/               # MCP・ツール設定
```

## ライセンス

MIT
