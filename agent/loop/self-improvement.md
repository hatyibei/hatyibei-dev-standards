# Self-Improvement Loop

A semi-automated loop that grafts hermes-agent's "skills auto-generated from sessions"
idea onto hatyibei-dev-standards. The LLM is never allowed to commit unattended —
human review is a mandatory gate.

## Overall flow

```
┌─────────────────────────────────────────────────────────┐
│  (1) Observe     Daily development                       │
│  ─────────────                                           │
│  During session → .harness/memory/inbox/                 │
│  SessionEnd     → inbox/ → daily/ (post-session.sh)      │
│  Score importance (memory-score.sh)                      │
│  Classify via Haiku → domains/ (memory-router.sh)        │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (2) Mine        Extract recurring patterns              │
│  ────────                                                │
│  tools/curation/mine-patterns.sh                         │
│  Aggregate decisions / errors / tools from 14 d of daily │
│  --summarize lets Haiku propose skill candidates         │
│  Output: skills/_generated/.candidates/                  │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (3) Propose     Draft a new skill                       │
│  ────────                                                │
│  tools/curation/propose-skill.sh <slug>                  │
│  Opus drafts SKILL.md using existing core/skills as few- │
│  shot examples. Marks status: proposed.                  │
│  Output: skills/_generated/YYYY-MM-DD-<slug>/            │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (4) Review      Human review (required)                 │
│  ────────                                                │
│  - Check for overlap with existing skills                │
│  - Validate anti-pattern notes                           │
│  - Run the example commands                              │
│  - Guard against over-engineering                        │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (5) Promote     extended/ → core/                       │
│  ─────────                                               │
│  tools/curation/promote.sh <slug> --target extended       │
│  Shows a checklist; the actual git add is manual         │
│  core/ promotion requires 3 months of extended/ usage     │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  (6) Observe     Re-measure usage                        │
│  ─────────                                               │
│  Update actually_used.md quarterly                       │
│  Unused skills: demote extended → _generated/ or delete  │
└─────────────────────────────────────────────────────────┘
```

## Cadence

| Step | Frequency | Auto / Manual |
|------|-----------|---------------|
| (1) Observe  | continuous | auto (hooks) |
| (2) Mine     | weekly | manual (`mine-patterns.sh`) |
| (3) Propose  | as needed | manual (`propose-skill.sh <slug>`) |
| (4) Review   | as needed | **human required** |
| (5) Promote  | as needed | manual (`promote.sh`) |
| (6) Observe  | quarterly | manual (update actually_used.md) |

## Prohibitions

- **No unattended LLM commits**: promotions from `_generated/` to `extended/` or `core/` must be performed by a human
- **No Opus-driven loops**: `propose-skill.sh` must not be cron-registered (cost & quality risk)
- **No overwriting existing skills**: if a proposal overlaps with an existing skill, stop at `_generated/`

## References

- Scripts: `tools/curation/{mine-patterns,propose-skill,promote}.sh`
- Shared lib: `tools/lib/claude-api.sh`
- ADR: [ADR-012](../../docs/adr/ADR-012-hermes-inspired-restructure.md)
- Promotion criteria: [ADR-009](../../docs/adr/ADR-009-core-selection-criteria.md)
- hermes parity map: [docs/hermes-parity.md](../../docs/hermes-parity.md)
