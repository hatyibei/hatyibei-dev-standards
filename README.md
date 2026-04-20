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
| [nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent) | 責務分離構造、自己改善ループ、FTS5 検索、personality system |

## 構造

```
CLAUDE.md                  Claude Code 用ハーネス設定
AGENTS.md                  Codex 用レビュー基準 (P0/P1/P2)

core/                      実績ベースの装備 (不可侵, 18 files)
  skills/                  11 skills (deploy, ux-audit, security-audit, ...)
  commands/                4 commands (plan, tdd, build-fix, onboard)
  agents/                  1 agent (planner)
  hooks/                   3 hooks (block-no-verify, config-protection, console-warn)
  rules/                   1 file (core-rules.md)

extended/                  参照専用 (不可侵)
  skills/                  advisor-strategy
  commands/                verify, refactor-clean, quality-gate, image-prompts, architecture
  agents/                  architect

archive/                   退避 (633 files, git history 保持、不可侵)

agent/                     エージェントの振る舞い定義 (ADR-012)
  personality/             Vane — キャラクター設定 + パラメータ + quips
  loop/                    self-improvement.md

tools/                     再利用可能な shell ユーティリティ (ADR-012)
  lib/                     claude-api.sh (共用ラッパ)
  search/                  fts-build.sh, recall.sh, index.schema.sql
  curation/                mine-patterns, propose-skill, promote
  personality/             quip.sh

skills/_generated/         Opus 生成候補 (未検証、PR マージは P0 ブロック)

plans/                     PlanMode 実装計画アーカイブ

cron/                      定期実行ジョブ集約 (README + crontab.sample)

.harness/
  memory/                  動的記憶 (.gitignore で実データ除外)
  hooks/                   記憶管理フック 5 本 (freshen/compost/score/router/post-session)
  companion/               Vane 互換保持 (hatchedAt 基点)

.github/
  workflows/codex-review.yml    Codex PR 自動レビュー
  codex/prompts/review.md       レビュープロンプト

docs/adr/                  ADR-001〜012
docs/hermes-parity.md      hermes-agent との対応表
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
| [ADR-010](docs/adr/ADR-010-memory-management-layer.md) | 記憶管理レイヤー |
| [ADR-011](docs/adr/ADR-011-advisor-strategy.md) | アドバイザー戦略 |
| [ADR-012](docs/adr/ADR-012-hermes-inspired-restructure.md) | hermes-agent 参考の再編 |

参考: [docs/hermes-parity.md](docs/hermes-parity.md) — hermes-agent との構成要素対応表。

## 使い方 (追加ツール)

```bash
# 記憶の想起 (FTS5 → grep フォールバック)
bash tools/search/recall.sh "pgvector"

# インデックス再構築 (6時間ごと cron 推奨)
bash tools/search/fts-build.sh

# スキル候補抽出 (直近14日の daily から)
bash tools/curation/mine-patterns.sh --summarize

# スキルドラフト生成 (Opus)
bash tools/curation/propose-skill.sh <slug>

# 昇格チェックリスト
bash tools/curation/promote.sh <YYYY-MM-DD-slug> --target extended

# Vane のコメント
bash tools/personality/quip.sh {success|fail|review-p0|review-p1|review-p2|idle}
```

## ライセンス

MIT
