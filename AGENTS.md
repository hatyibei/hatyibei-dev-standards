# AGENTS.md

> Claude Code writes. Codex reviews. Cross-validation between two different biases.
> Language policy: agent-facing = EN, human-facing = JP ([ADR-012](./docs/adr/ADR-012-hermes-inspired-restructure.md) §6).

## Project structure

```
core/               — skills 11, commands 4, agent 1, hooks 3, rules 1 (inviolable)
extended/           — reference-only skills 1, commands 5, agents 1 (inviolable)
archive/            — retired definitions, git history preserved, 633 files (inviolable)
agent/              — personality (Vane) + self-improvement loop
tools/              — lib / search / curation / personality shell utilities
skills/_generated/  — Opus-drafted candidates, unverified (PR merge = P0 block)
plans/              — PlanMode implementation plans (archive)
cron/               — scheduled job definitions
docs/adr/           — ADR-001..012
```

## Coding standards

- Conventional Commits: `type(scope): description`
- File names: lowercase with hyphens
- Prefer relative imports
- Error handling only at system boundaries
- No premature abstraction (YAGNI)
- `--no-verify` / `--no-gpg-sign` are forbidden

## Testing

- TDD: RED → GREEN → REFACTOR
- Adding a feature without a test is a P0 violation

## Review guidelines

### P0 — Block (any hit → request changes)

- Trace of `--no-verify` or `--no-gpg-sign`
- Hardcoded secrets (API keys, tokens, passwords, committed `.env`)
- Server secrets exposed via `NEXT_PUBLIC_*`
- Feature added without tests
- Missing auth protection on a protected API route
- Missing Stripe webhook signature verification
- XSS (`dangerouslySetInnerHTML`, unsanitized DOM insertion)
- SQL / command / prompt injection
- PII or credentials emitted via `console.log`
- Build does not pass
- Promoting any `skills/_generated/**` draft directly into `core/` or `extended/` without running `promote.sh`

### P1 — Flag (request fix)

- Residual `console.log` / `console.debug` / `console.info`
- Commit message not in Conventional Commits format
- One PR mixing unrelated logical changes (1 PR = 1 concern)
- Loosening a linter / formatter config without justification
- `any` type usage or excessive type assertions
- Missing error handling for external API calls
- Significant test coverage drop

### P2 — Suggest (improvement only)

- Remaining `TODO` / `FIXME` comments
- Diff > 500 lines (suggest splitting the PR)
- Inconsistent naming
- Dead code / stale comments
- Import order issues

## Behavioral constraints

- Review only the diff of the PR. Do not propose improvements to unchanged code
- Comment in Japanese (human reviewer language)
- Include a code example with every fix proposal
- P0 → request changes; P1 only → approve with comments; P2 only → approve
- Quote the offending line when flagging a security issue
- Verify surrounding context before reporting, to avoid false positives
