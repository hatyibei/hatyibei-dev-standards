---
name: review-fix-loop
description: Self-driving loop that runs review -> fix -> re-review on a PR/branch until it converges, so humans don't have to babysit the screen
origin: self
allowed-tools: Bash(git:*), Bash(npm:*), Bash(pnpm:*), Bash(yarn:*), Read, Edit, Grep, Glob, Skill
argument-hint: PR number or branch name (defaults to current branch)
model: opus
---

# Review-Fix Loop

Self-driving skill for parallel work, so you stop watching the screen.
Against a PR or branch, it loops `code-review` -> fix -> re-review,
and keeps going to the end as long as no human judgment is required.

Reference: [What we did to stop babysitting the screen during parallel Claude Code work](https://zenn.dev/pepabo/articles/claude-code-stop-watching-parallel-work)

## When to Activate

- Fire a PR at night and expect it cleaned up by morning
- Running 5-6 panes in parallel and want one pane dedicated to review-fix
- Knock out CI/Codex findings in bulk
- As a pre-step before manual review, to clean up mechanically fixable findings first

## When NOT to Activate

- Changes involving architectural judgment (use `advisor-strategy`)
- Initial design review (a human should cross-check with the spec)
- Root-cause security vulnerability work (use `security-audit` skill)

## Principles of Self-Driving

1. **Don't ask the human**: if ambiguous, record as "deferred" and continue
2. **Don't widen scope**: no out-of-task refactors or feature additions
3. **Deterministic termination**: the loop must terminate in a finite number of iterations
4. **Leave evidence**: each iteration's findings and fixes are recorded append-only

## Input

- No args -> auto-detect the open PR tied to the current branch
- PR number -> locate with `gh pr view <N>`
- Branch name -> get the linked PR via `gh pr list --head <branch>`

## Execution Loop

```
iteration = 1
MAX_ITERATIONS = 3
findings_log = []

while iteration <= MAX_ITERATIONS:
  1. diff = git diff origin/main...HEAD
  2. findings = run_review(diff)           # code-review skill
  3. if no P0/P1 findings:
       break  # converged
  4. fixable, unfixable = partition(findings)
  5. apply_fixes(fixable)
  6. run_tests()                           # quality gate
  7. if tests fail:
       revert_last_fix()
       mark unfixable
       break
  8. commit(message)                       # Conventional Commits
  9. findings_log.append({iteration, findings, fixes})
  iteration += 1

report(findings_log, unfixable)
```

## Step Details

### 1. Review phase

Review the diff using the `core/skills/code-review` lens. Extract findings with priority:

- **P0** (must fix): security, type errors, test failures, build errors
- **P1** (recommended): naming, DRY violations, missing error handling, magic numbers
- **P2** (record only): style, missing comments

### 2. Partition phase (fixable vs unfixable)

**Fixable** — safe to auto-fix:
- Naming consistency
- Unneeded complexity reduction (equivalent to `simplify` skill)
- Adding error handling
- Type annotation fixes
- Import order / unused imports
- Lint/formatter findings

**Unfixable** — record and move on; requires human judgment:
- Findings with multiple valid spec interpretations
- Findings requiring architectural changes
- Breaking API changes
- Auth/authorization logic changes

### 3. Fix phase

1. For each fixable finding, apply the minimal diff
2. Split changes into 1 logical unit = 1 commit
3. Conventional Commits format: `fix(scope): ...`, `refactor(scope): ...`

### 4. Quality gate

Before committing a fix, always run:
- `npm test` / `pnpm test` / project's default test command
- Build (if configured)
- Lint (if configured)

If any fails:
1. `git reset --soft HEAD~1` to undo the latest fix
2. Downgrade that finding to `unfixable` and log it
3. Continue the loop (other findings may still be processable)

### 5. Termination conditions

Terminate on any of:

| Condition | Reason |
|------|----------|
| 0 P0/P1 findings | Converged (success) |
| `iteration > MAX_ITERATIONS` | Iteration cap |
| No new findings for 2 consecutive iterations | Infinite-loop guard |
| Tests/build unrecoverable by fix | Human intervention required |

## Output report

At session end, emit the loop result to stdout in the format below.
Optimize for "user comes back and gets it at a glance".

```markdown
## Review-Fix Loop complete

**Target**: PR #123 (feat: add payment flow)
**Branch**: feature/payment-flow
**Iterations**: 2 / 3
**Result**: Converged / Cap reached / Intervention required

### Fix summary
| # | Iteration | Fixed | Commits |
|---|-----------|-------|---------|
| 1 | 1         | 4     | 2       |
| 2 | 2         | 2     | 1       |

### Open (needs human judgment)
- [P1] `src/payment/charge.ts:42` — 3D Secure handling unclear in spec
- [P1] `src/api/webhook.ts:15` — whether to bump Stripe version

### Next actions
- [ ] Human reviews the unfixable items above
- [ ] "Ready for human review" label has been added to PR
```

## Interop with other skills

- Call `code-review` during the review phase
- Call `simplify` for fixes in certain categories
- After convergence, call `commit-push-pr` to push the PR to its latest state

## Known pitfalls

- **Project without tests**: treat as quality-gate fail and fix conservatively by eyeballing the diff
- **Large P2 volume**: P2 is record-only. This loop does not fix them
- **Conflict with CI's Codex review**: commits written by this loop get re-reviewed by Codex.
  Codex's findings become the input to the next iteration — that is the design (GAN-style cross-check)

## Memory recording

At loop end, append the following to `.harness/memory/inbox/review-fix-loop-YYYY-MM-DD.md`:

```yaml
---
date: <today>
pr: <PR number>
iterations: <count>
fixed_count: <count>
unfixable: <count>
importance: 1.2  # fix family +0.2
---

## Learnings this time
- <record any finding that can be patterned>
- <record any failure likely to recur>
```

The post-session hook aggregates it into daily/.
