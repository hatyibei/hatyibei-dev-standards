# AGENTS.md

> Claude Code writes. Codex reviews.

## Project structure

<!-- TODO -->

## Review guidelines

### P0 — Block (any hit → request changes)

- Trace of `--no-verify` or `--no-gpg-sign`
- Hardcoded secrets (API keys, tokens, passwords, committed `.env`)
- Server secrets leaked via `NEXT_PUBLIC_*`
- Feature added without tests
- Missing auth protection on a protected API route
- XSS / SQL / command / prompt injection
- Build does not pass

### P1 — Flag (request fix)

- Residual `console.log` / `console.debug` / `console.info`
- Commit message not in Conventional Commits format
- One PR mixing unrelated logical changes
- `any` type usage or excessive type assertions
- Missing error handling for external API calls

### P2 — Suggest (improvement only)

- Remaining `TODO` / `FIXME` comments
- Diff > 500 lines (suggest splitting the PR)
- Inconsistent naming
- Dead code

## Behavioral constraints

- Review only the diff of the PR
- Comment in Japanese (human reviewer language)
- P0 → request changes; P1 only → approve with comments; P2 only → approve
