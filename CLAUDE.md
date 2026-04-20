# hatyibei 開発標準 — Core Harness

> 12 ヶ月の使用実績ベース ([ADR-009](./docs/adr/ADR-009-core-selection-criteria.md))。**二刀流**: Claude Code (書く) × Codex (検査、`AGENTS.md`)。

## 基本原則

1. **Plan Before Execute** — 書く前に計画
2. **Test First** — RED → GREEN → REFACTOR
3. **Verify Before Complete** — 完了宣言前にテスト通過確認
4. **Evidence Over Claims** — 「動くはず」ではなく「動いた証拠」

## 適応的深度

- **minimal** (typo/設定): 直接修正 → テスト → コミット
- **standard** (機能/バグ): 計画 → TDD → レビュー → コミット
- **comprehensive** (設計変更): ブレスト → 設計 → 計画 → TDD → 2段階レビュー。advisor: [extended/skills/advisor-strategy](./extended/skills/advisor-strategy/SKILL.md)

## サブエージェント

- **推奨**: `general-purpose` に具体的ファイルパス+変更内容で委譲 (`Explore`=調査, `planner`=設計)
- 「調査結果に基づいて修正して」は禁止

## 品質ゲート

既存テスト全パス / 認証情報混入なし / ビルド成功 / 動作確認。規約: [core/rules/core-rules.md](./core/rules/core-rules.md)

## 夜間自律実行 (`--dangerously-skip-permissions`)

フック 3 本発火: `block-no-verify` (hard fail) / `config-protection` (warn) / `console-warn` (warn)。Conventional Commits 必須、force push to main 禁止。

## Codex 連携

`PR → codex-review.yml → AGENTS.md 基準で Codex レビュー`。Secrets に `OPENAI_API_KEY`、導入は `bash install.sh`。

## 記憶・想起・自己改善

| Tier | いつ | 対象 |
|------|------|------|
| 0 | 朝初回 | weekly summary + 昨日 daily |
| 1 | 毎回 | CLAUDE.md + core/ |
| 2-3 | 毎回 | memory/daily today + summaries/ 直近 7 件 |
| 4 | オンデマンド | `bash tools/search/recall.sh <q>` (FTS5、grep fallback) |

- 記録: `echo "..." > .harness/memory/inbox/<slug>.md` → ルータ: `bash .harness/hooks/memory-router.sh` (Haiku、conf<0.7 で Opus)
- スキル自動生成 (semi-auto、**LLM 自動コミット禁止**): `tools/curation/{mine-patterns,propose-skill,promote}.sh`
- Vane: `bash tools/personality/quip.sh {success|fail|review-p0|p1|p2|idle}`
- 詳細: [ADR-010](./docs/adr/ADR-010-memory-management-layer.md) / [ADR-012](./docs/adr/ADR-012-hermes-inspired-restructure.md) / [self-improvement.md](./agent/loop/self-improvement.md)

## ファイル構造

- **不可侵**: `core/` (skills 11 / cmd 4 / planner / hooks 3 / rules) / `extended/` / `archive/` / `.harness/hooks/` / `.harness/memory/*/`
- **追加 (ADR-012)**: `agent/{personality,loop}/` / `tools/{lib,search,curation,personality}/` / `skills/_generated/` / `plans/` / `cron/`
- 対応表: [docs/hermes-parity.md](./docs/hermes-parity.md)
