# hatyibei 開発標準 — Core Harness

> このハーネスは actually_used.md に基づき、12ヶ月間の使用実績があるもののみで構成されている。
> 詳細な選定根拠: [ADR-009](./docs/adr/ADR-009-core-selection-criteria.md)
>
> **二刀流構成**: Claude Code（書く側）× Codex（検査する側）
> - `CLAUDE.md` → Claude Code CLI 用（ローカル開発・夜間自律実行）
> - `AGENTS.md` → Codex 用（CI/CD レビュー・PR 自動検査）

## 基本原則

1. **Plan Before Execute**: コードを書く前に計画を立てる
2. **Test First**: テストを先に書く (RED-GREEN-REFACTOR)
3. **Verify Before Complete**: 完了宣言前にテスト通過を確認
4. **Evidence Over Claims**: 「動くはず」ではなく「動いた証拠」

## 適応的深度

タスクの複雑さで深度を判定:
- **minimal** (typo/設定変更): 直接修正 → テスト → コミット
- **standard** (機能追加/バグ修正): 計画 → TDD → レビュー → コミット
- **comprehensive** (アーキテクチャ変更): ブレスト → 設計 → 計画 → TDD → 2段階レビュー → コミット
  → advisor パターン参照: [extended/skills/advisor-strategy/SKILL.md](./extended/skills/advisor-strategy/SKILL.md)

## サブエージェント活用

- 独立タスクは並列でサブエージェントに委譲
- **推奨: `general-purpose` に具体的な指示を渡す**（専門agent定義より実績あり）
- `Explore` エージェント: 調査・検索
- `planner` エージェント: 設計・計画（唯一 agentType 指定で実績あり）
- Worktree: 隔離環境での実験
- 「調査結果に基づいて修正して」は禁止 — 具体的なファイルパス・変更内容を渡す

## コーディング規約

→ [core/rules/core-rules.md](./core/rules/core-rules.md)

## 品質ゲート（必須）

全てのコード変更で以下を通過:
1. 既存テストが全てパス
2. セキュリティチェック（認証情報の混入なし）
3. ビルド成功
4. 変更の動作確認

## 夜間自律実行モード

`--dangerously-skip-permissions` での実行時の安全設定:
- Hook 3本が自動で発火し、危険操作をブロック/警告する
- `block-no-verify.sh`: `--no-verify`, `--no-gpg-sign` を hard fail
- `config-protection.sh`: linter/formatter 設定変更を soft warn
- `console-warn.sh`: console.log 残留を soft warn
- コミットは必ず Conventional Commits 形式
- force push to main/master は禁止

## CI/CD: Codex 連携

Claude Code が書いたコードを Codex が自動レビューする GAN-Style 交差検証:

```
夜間: Claude Code → feature branch にコード → commit-push-pr で PR 作成
  ↓
CI: Codex Action 自動起動 → AGENTS.md の基準でレビュー
  ↓
朝: P0 → Request Changes / P0 なし → Approve → レビュー済み PR が待っている
```

- ワークフロー: `.github/workflows/codex-review.yml` (PR open/sync/reopen で自動起動)
- プロンプト: `.github/codex/prompts/review.md`
- レビュー基準: `AGENTS.md` の Review guidelines (P0/P1/P2)
- 認証: `OPENAI_API_KEY` を GitHub Secrets に設定

**各repoへの導入:**
```bash
cd ~/Claude/対象プロジェクト && bash ~/Claude/hatyibei-dev-standards/install.sh
gh secret set OPENAI_API_KEY -R hatyibei/対象リポジトリ
```

## 記憶管理レイヤー (.harness/memory/)

セッション間で学習を蓄積する動的記憶システム。静的コンテキスト（CLAUDE.md, SKILL.md）を補完する。

### コンテキスト注入階層

| Tier | いつ | 対象 | 説明 |
|------|------|------|------|
| **Tier 0** | 朝初回のみ | `summaries/latest-weekly.md` + 昨日の `daily/` | Morning Briefing |
| **Tier 1** | 毎回 | `CLAUDE.md` + `core/skills/` + `core/rules/` | 静的コンテキスト |
| **Tier 2** | 毎回 | `memory/daily/YYYY-MM-DD.md` | 今日の生ログ |
| **Tier 3** | 毎回 | `memory/summaries/` 直近7件 | 直近7日の要約 |
| **Tier 4** | オンデマンド | `memory/domains/` を grep | 「思い出して」「過去の判断」等で検索 |

### ディレクトリ構造

```
.harness/memory/
├── inbox/              セッション中の学び・判断を一時保存（生データ）
├── daily/              日次ログ YYYY-MM-DD.md（Tier 2）
├── summaries/          日次要約・週次要約（Tier 3）
├── domains/            分野別記憶（Tier 4）
│   ├── dev/            patterns.md, decisions.md, learnings.md
│   ├── product/        Versonova, gen-diag 等
│   └── biz/            SCC業務, 組織戦略
└── compost/            削除候補（90日超）
```

### フック

| スクリプト | トリガー | 処理 |
|-----------|---------|------|
| `post-session.sh` | SessionEnd | inbox/ → daily/ に転記、inbox/ クリア |
| `memory-freshen.sh` | cron 毎日06:00 | 7日超の daily → summaries に Haiku 要約圧縮 |
| `memory-compost.sh` | cron 90日ごと | 90日超を compost/ に移動、365日超を完全削除 |
| `memory-score.sh` | post-session後 + cron毎日 | キーワードでimportance算出 + 日次×0.95減衰 |
| `memory-router.sh` | 手動 or watch | Haiku で domain 分類、confidence<0.7 で Opus エスカレーション |

### importance スコアリング

daily/ の各エントリに YAML frontmatter で重要度を付与:
```yaml
---
date: 2026-04-10
importance: 1.8
freshness: fresh
---
```

**加算ルール:**
| キーワード | 加算 |
|-----------|------|
| 基礎 | 1.0 |
| 意思決定 (decided, chose, rejected, 決定, 判断) | +0.5 |
| アーキテクチャ (architect, 設計, ADR, migration) | +0.3 |
| セキュリティ (security, 脆弱性, CVE, XSS) | +0.3 |
| エラー・修正 (error, bug, fix, 障害) | +0.2 |
| パフォーマンス (latency, cache, 最適化) | +0.2 |
| コスト (cost, pricing, budget) | +0.2 |

**減衰:** 毎日 importance × 0.95。0.1 未満は 0.0 に切り捨て。

### Haiku→Opus ルーティング

inbox/ のエントリを自動分類:
1. **Haiku** で domain (dev/product/biz) + importance + confidence を算出
2. **confidence < 0.7** → **Opus** にエスカレーションして再分類
3. 分類結果を `domains/{domain}/learnings.md` に蓄積

```bash
# ワンショット実行
bash .harness/hooks/memory-router.sh

# 10分ごとの監視モード
bash .harness/hooks/memory-router.sh watch
```

### セッション中の学びの記録方法

セッション中に重要な学び・判断があったら inbox/ に書き出す:
```bash
echo "## 判断: Redis → PostgreSQL pgvector に変更
理由: コスト。100K vectors 以下なら pgvector で十分。" > .harness/memory/inbox/redis-to-pgvector.md
```

SessionEnd 時に `post-session.sh` が自動で daily/ に集約する。

### 記憶の鮮度ライフサイクル

```
fresh (0-7日) → summarized (7-90日) → composted (90-365日) → deleted (365日超)
```

## ファイル構造

```
core/                          ← 常時ロード（18ファイル）
  skills/                      ← 実発火実績のある10 skill + 自走型 1 skill
    deploy/                    ← 6 Skill calls, commit 22件
    ux-audit/                  ← 4 Skill + 9 手入力, Playwright巡回
    security-audit/            ← 2 Skill + 7 手入力, Round 1-5監査
    spec-review/               ← 2 Skill + 6 手入力, リリース前ゲート
    e2e-test/                  ← 1 Skill + 5 手入力
    code-review/               ← 1 Skill + subagent, XSS検出実績
    simplify/                  ← 1 Skill + 3 subagent, 3並列レビュー
    ci-status/                 ← CI障害時の原因分析
    stripe-debug/              ← Stripe Webhook障害デバッグ
    commit-push-pr/            ← PR作成・リリース時
    review-fix-loop/           ← 新設 (2026-04-15), 並列自走用 — 張り付き監視を手放す
  commands/                    ← 実発火実績のある4 command
    plan.md                    ← PlanMode 11セッション
    tdd.md                     ← TDD workflow shim
    build-fix.md               ← ビルド修復
    onboard.md                 ← 新リポジトリ探索
  agents/
    planner.md                 ← agentType指定で発火実績あり
  hooks/                       ← 自作3本（1,700+ events で稼働確認済み）
    block-no-verify.sh         ← PreToolUse:Bash (hard fail)
    config-protection.sh       ← PreToolUse:Edit|Write (soft warn)
    console-warn.sh            ← PostToolUse:Edit (soft warn)
  rules/
    core-rules.md              ← ECC guardrails + コミット規約統合

extended/                      ← 明示的に呼んだときだけロード
  skills/
    advisor-strategy/          ← 判断エスカレーション運用パターン (ADR-011)
  commands/
    verify.md                  ← quality-gate + CI で代替可能
    refactor-clean.md          ← simplify で代替可能
    quality-gate.md            ← CI設定の判断材料
    image-prompts.md           ← 画像生成プロンプト設計
    architecture.md            ← ADR作成の文脈で参照
  agents/
    architect.md               ← planner で代替されているが参照実績あり

.harness/
  memory/                      ← 動的記憶（.gitignore で実データ除外）
    inbox/                     ← セッション中の一時保存
    daily/                     ← 日次ログ（Tier 2）
    summaries/                 ← 要約（Tier 3）
    domains/{dev,product,biz}/ ← 分野別記憶（Tier 4）
    compost/                   ← 削除候補
  hooks/                       ← 記憶管理フック 3本

archive/                       ← 退避（git history 保持、削除ではない）
  unused-agents/               ← 35 agents
  unused-commands/             ← 69 commands
  unused-skills/               ← 160+ skills
  unused-hooks/                ← 41 hooks + ecc-scripts
  unused-configs/              ← 5 configs + ecc-rules
  reference-docs/              ← claude-mem, aidlc, superpowers

AGENTS.md                      ← Codex 用レビュー基準 (P0/P1/P2)
.github/
  workflows/codex-review.yml   ← PR 自動レビュー (openai/codex-action@v1)
  codex/prompts/review.md      ← レビュープロンプト
.codex/config.toml             ← Codex プロジェクト設定
install.sh                     ← 各repo導入スクリプト

docs/adr/                      ← ADR-001〜009（変更なし）
actually_used.md               ← 使用実態レポート（選定の根拠データ）
```

## extended/ の使い方

extended/ のスキルを使いたいときは、該当ファイルのパスを直接 Claude に読ませる:
```
このファイルを読んで従って: extended/commands/architecture.md
```

## 参考ADR

- ADR-001〜008: 開発ライフサイクル・TDD・メモリ・スキル・フック・サブエージェント・レビュー・品質ゲート
- [ADR-009: Core選定基準](./docs/adr/ADR-009-core-selection-criteria.md) ← **3層分離の判断根拠**
- [ADR-010: 記憶管理レイヤー](./docs/adr/ADR-010-memory-management-layer.md) ← **動的記憶の設計**
- [ADR-011: アドバイザー戦略](./docs/adr/ADR-011-advisor-strategy.md) ← **advisor/reviewer/subagent の役割定義**
