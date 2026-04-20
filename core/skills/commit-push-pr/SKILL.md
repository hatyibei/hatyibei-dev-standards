---
name: commit-push-pr
description: Run commit, push, and PR creation in one go
origin: plugin (commit-commands)
allowed-tools: Bash(git:*), Bash(gh:*)
---

Commit the current changes, push to remote, and open a PR.

## Procedure

1. Check current changes with `git status` and `git diff HEAD`
2. Check current branch with `git branch --show-current`
3. If on main, create a new branch
4. Create a single commit with a message appropriate for the changes
5. Push the branch to origin
6. Create a pull request with `gh pr create`

## Rules

- Execute all steps in one response
- Commit message uses Conventional Commits
- PR title stays within 70 characters
