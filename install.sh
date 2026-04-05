#!/bin/bash
# install.sh — 対象repoに Codex レビューレイヤーを導入
#
# Usage:
#   cd ~/Claude/AI-Driven-Diagnosis-Platform
#   bash ~/Claude/hatyibei-dev-standards/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"

echo "=== Codex Layer Install ==="
echo "Target: $REPO_ROOT ($REPO_NAME)"
echo ""

# 1. AGENTS.md
if [ -f "$REPO_ROOT/AGENTS.md" ]; then
  echo "[SKIP] AGENTS.md"
else
  cp "$SCRIPT_DIR/templates/AGENTS.md" "$REPO_ROOT/AGENTS.md"
  sed -i "s/<!-- TODO -->/$REPO_NAME/" "$REPO_ROOT/AGENTS.md"
  echo "[OK]   AGENTS.md"
fi

# 2. Workflow
mkdir -p "$REPO_ROOT/.github/workflows" "$REPO_ROOT/.github/codex/prompts"
if [ -f "$REPO_ROOT/.github/workflows/codex-review.yml" ]; then
  echo "[SKIP] .github/workflows/codex-review.yml"
else
  cp "$SCRIPT_DIR/.github/workflows/codex-review.yml" "$REPO_ROOT/.github/workflows/"
  echo "[OK]   .github/workflows/codex-review.yml"
fi

# 3. Prompt
if [ -f "$REPO_ROOT/.github/codex/prompts/review.md" ]; then
  echo "[SKIP] .github/codex/prompts/review.md"
else
  cp "$SCRIPT_DIR/.github/codex/prompts/review.md" "$REPO_ROOT/.github/codex/prompts/"
  echo "[OK]   .github/codex/prompts/review.md"
fi

# 4. .codex/config.toml
mkdir -p "$REPO_ROOT/.codex"
if [ -f "$REPO_ROOT/.codex/config.toml" ]; then
  echo "[SKIP] .codex/config.toml"
else
  cp "$SCRIPT_DIR/.codex/config.toml" "$REPO_ROOT/.codex/config.toml"
  echo "[OK]   .codex/config.toml"
fi

# 5. Check OPENAI_API_KEY
echo ""
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ -n "$REMOTE_URL" ]; then
  OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/](.+)\.git$|\1|; s|.*github\.com[:/](.+)$|\1|')
  if command -v gh &>/dev/null; then
    if gh secret list -R "$OWNER_REPO" 2>/dev/null | grep -q "OPENAI_API_KEY"; then
      echo "[OK]   OPENAI_API_KEY secret is set"
    else
      echo "[TODO] gh secret set OPENAI_API_KEY -R $OWNER_REPO"
    fi
  fi
fi

echo ""
echo "Done. git add & commit, then PRを出せばレビューが走る。"
