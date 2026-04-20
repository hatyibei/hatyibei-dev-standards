# Core Rules

Consolidated rules based on ECC guardrails and actual development practice.

## Commit Conventions

- **Format**: Conventional Commits — `type(scope): description`
- **prefix**: feat, fix, test, docs, ci, chore, perf, refactor, ux, design
- **One commit = one logical change**
- `--no-verify` is forbidden (enforced by hook `block-no-verify.sh`)
- Use `--amend` only when explicitly instructed
- Declare AI collaboration via a Co-Authored-By header

## Code Style

- **File naming**: lowercase with hyphens (e.g. `session-start.js`)
- **Imports**: prefer relative imports
- **Functions**: prefer the `function` keyword over arrow functions (at top level)
- **Error handling**: validate only at system boundaries (user input, external APIs)
- **Abstraction**: even if similar code appears 3 times, prefer direct writing over premature abstraction (YAGNI)

## Review

- Two-stage: spec conformance -> code quality
- Review the whole PR diff (not only the latest commit)
- 1 PR = 1 problem
- Prefer reviews with confidence scores (can be automated with `/loop code-review`)

## Security

- Always keep OWASP Top 10 in mind
- Never commit credentials
- Stripe Webhook signature verification is mandatory
- Guard against prompt injection (when integrating with Vertex AI)
- Track audit fixes with the `fix(security):` prefix

## Quality Gate (mandatory)

Every code change must pass all of the following:
1. All existing tests pass
2. Security check (no credential leakage)
3. Build succeeds
4. Manual verification of the change's behavior

## Hook Wiring

```
settings.json:
├── PreToolUse
│   ├── Bash       → core/hooks/block-no-verify.sh  (hard fail)
│   └── Edit|Write → core/hooks/config-protection.sh (soft warn)
└── PostToolUse
    └── Edit       → core/hooks/console-warn.sh      (soft warn)
```

## Architecture (ECC-derived)

- Maintain the `hybrid` module layout
- Test layout: `separate` (test files are kept apart from sources)
- Markdown/Agent files: YAML frontmatter required (`name`, `description`)
