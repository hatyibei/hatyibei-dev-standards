# hatyibei-dev-standards

hatyibei の AI 駆動開発標準 — Claude Code × Codex 二刀流ハーネス

## 概要

12ヶ月間の使用実態調査に基づき、660+ ファイルを core/extended/archive の 3 層に分離。
Claude Code（書く側）と Codex（検査する側）で異なるバイアスの交差検証を行う。

- **CLAUDE.md** → Claude Code CLI 用（ローカル開発・夜間自律実行）
- **AGENTS.md** → Codex 用（PR 自動レビュー）

### ソースリポジトリ

| リポジトリ | 抽出した知見 |
|-----------|------------|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | エージェント・スキル・フックの包括的フレームワーク |
| [claude-mem](https://github.com/thedotmack/claude-mem) | 永続メモリと知識管理の設計思想 |
| [aidlc-workflows](https://github.com/awslabs/aidlc-workflows) | AI駆動開発ライフサイクル、適応的深度 |
| [superpowers](https://github.com/obra/superpowers) | 構造化ワークフロー、TDD、サブエージェント駆動開発 |

## 構造

```
CLAUDE.md                  Claude Code 用ハーネス設定
AGENTS.md                  Codex 用レビュー基準 (P0/P1/P2)

core/                      実績ベースの装備 (21 files)
  skills/                  10 skills (deploy, ux-audit, security-audit, ...)
  commands/                4 commands (plan, tdd, build-fix, onboard)
  agents/                  1 agent (planner)
  hooks/                   3 hooks (block-no-verify, config-protection, console-warn)
  rules/                   1 file (core-rules.md)

extended/                  参照専用 (6 files)
  commands/                verify, refactor-clean, quality-gate, image-prompts, architecture
  agents/                  architect

archive/                   退避 (633 files, git history 保持)

.github/
  workflows/codex-review.yml    Codex PR 自動レビュー
  codex/prompts/review.md       レビュープロンプト

docs/adr/                  ADR-001〜009
```

## セットアップ

### 1. GitHub Secrets に OpenAI API Key を設定

Codex GitHub Action は `OPENAI_API_KEY` を必要とする。

```bash
# gh CLI で設定
gh secret set OPENAI_API_KEY -R hatyibei/hatyibei-dev-standards

# または GitHub Web UI:
# Settings → Secrets and variables → Actions → New repository secret
# Name: OPENAI_API_KEY
# Value: sk-...
```

### 2. 他のリポジトリに導入

```bash
cd ~/Claude/対象プロジェクト
bash ~/Claude/hatyibei-dev-standards/install.sh
```

各リポジトリにも `OPENAI_API_KEY` を設定すること:

```bash
gh secret set OPENAI_API_KEY -R hatyibei/対象リポジトリ
```

## ADR 一覧

| ID | タイトル |
|----|---------|
| [ADR-001](docs/adr/ADR-001-ai-driven-development-lifecycle.md) | AI駆動開発ライフサイクル |
| [ADR-002](docs/adr/ADR-002-test-driven-development.md) | テスト駆動開発 |
| [ADR-003](docs/adr/ADR-003-persistent-memory-system.md) | 永続メモリシステム |
| [ADR-004](docs/adr/ADR-004-skill-based-architecture.md) | スキルベースアーキテクチャ |
| [ADR-005](docs/adr/ADR-005-hook-driven-automation.md) | フック駆動自動化 |
| [ADR-006](docs/adr/ADR-006-subagent-driven-development.md) | サブエージェント駆動開発 |
| [ADR-007](docs/adr/ADR-007-code-review-protocol.md) | コードレビュープロトコル |
| [ADR-008](docs/adr/ADR-008-quality-gates-and-adaptive-depth.md) | 品質ゲートと適応的深度 |
| [ADR-009](docs/adr/ADR-009-core-selection-criteria.md) | Core選定基準 |

## ライセンス

MIT
