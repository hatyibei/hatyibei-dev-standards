# hatyibei dev standards — Core Harness

> Distilled from 12 months of usage data ([ADR-009](./docs/adr/ADR-009-core-selection-criteria.md)).
> **Dual-model**: Claude Code writes, Codex reviews (`AGENTS.md`).
> Language policy: agent-facing = EN, human-facing = JP ([ADR-012](./docs/adr/ADR-012-hermes-inspired-restructure.md) §6).

## Principles

1. **Plan Before Execute** — draft a plan before writing code
2. **Test First** — RED → GREEN → REFACTOR
3. **Verify Before Complete** — confirm tests pass before claiming done
4. **Evidence Over Claims** — not "should work" but "did work"

## Adaptive Depth

- **minimal** (typo, config): edit → test → commit
- **standard** (feature, bug): plan → TDD → review → commit
- **comprehensive** (design change): brainstorm → design → plan → TDD → 2-stage review. Advisor: [extended/skills/advisor-strategy](./extended/skills/advisor-strategy/SKILL.md)

## Subagents

- **Preferred**: delegate to `general-purpose` with concrete file paths + changes (more proven than specialized agents)
- `Explore` = research, `planner` = design (the only agentType with firing record)
- Forbidden: "based on your findings, fix it" — always supply paths + exact changes

## Quality Gates (required)

All existing tests pass / no secrets in diff / build succeeds / behavior verified. Rules: [core/rules/core-rules.md](./core/rules/core-rules.md)

## Autonomous Night Mode (`--dangerously-skip-permissions`)

Three hooks fire: `block-no-verify` (hard fail), `config-protection` (warn), `console-warn` (warn). Conventional Commits required. Force-push to main is forbidden.

## Codex Integration

`PR → codex-review.yml → Codex reviews per AGENTS.md`. Put `OPENAI_API_KEY` in GitHub Secrets. Install in a repo: `bash install.sh`.

## Memory, Recall, Self-Improvement

| Tier | When | Source |
|------|------|--------|
| 0 | first session of day | weekly summary + yesterday's daily |
| 1 | every turn | CLAUDE.md + core/ |
| 2-3 | every turn | memory/daily today + last 7 summaries |
| 4 | on demand | `bash tools/search/recall.sh <q>` (FTS5, grep fallback) |

- Record: `echo "..." > .harness/memory/inbox/<slug>.md` → router: `bash .harness/hooks/memory-router.sh` (Haiku classifies; conf<0.7 escalates to Opus)
- Skill auto-gen (semi-auto, **no LLM auto-commit**): `tools/curation/{mine-patterns,propose-skill,promote}.sh`
- Vane quips: `bash tools/personality/quip.sh {success|fail|review-p0|p1|p2|idle}`
- Details: [ADR-010](./docs/adr/ADR-010-memory-management-layer.md) / [ADR-012](./docs/adr/ADR-012-hermes-inspired-restructure.md) / [self-improvement.md](./agent/loop/self-improvement.md)

## Layout

- **Inviolable** (structure/semantics frozen): `core/` (skills 11, cmd 4, planner, hooks 3, rules) / `extended/` / `archive/` / `.harness/hooks/` / `.harness/memory/*/`
- **Added (ADR-012)**: `agent/{personality,loop}/` / `tools/{lib,search,curation,personality}/` / `skills/_generated/` / `plans/` / `cron/`
- Parity map: [docs/hermes-parity.md](./docs/hermes-parity.md)
