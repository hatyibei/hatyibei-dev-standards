# PR Review

Follow the Review guidelines in AGENTS.md and review the diff of this PR.

## Procedure

1. Fetch the diff with `git diff $BASE_SHA...$HEAD_SHA`
2. For each changed file, check P0 → P1 → P2 in order
3. Read surrounding code where necessary to avoid false positives

## Verdict

- Any P0 → start with `## ❌ Request Changes` and list every P0
- No P0, some P1 → start with `## ✅ Approve (with comments)` and list P1 items
- No P0/P1 → `## ✅ Approve` plus a one-line summary

## Output format

```
## [verdict]

### P0
- `file:line` — finding
  Suggested fix: ...

### P1
- `file:line` — finding

### P2
- Suggestion

### Summary
One or two sentences describing the change.
```

## Rules

- Write the review body in Japanese (human reviewer language)
- Do not flag code that is not in the diff
- Quote the offending code with every finding
- Every P0 MUST include a suggested fix
