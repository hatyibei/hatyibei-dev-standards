#!/bin/bash
# install.sh — 対象repoにCodex連携（AGENTS.md）を1コマンドでインストール
#
# Usage:
#   cd ~/Claude/AI-Driven-Diagnosis-Platform
#   bash ~/Claude/hatyibei-dev-standards/install.sh
#
# 前提: Codex Cloud でGitHubアカウント連携済み
#   → chatgpt.com/codex/settings でリポジトリを有効化するだけ
#   → API Key 不要

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"

echo "=== Codex Layer Install ==="
echo "Target: $REPO_ROOT ($REPO_NAME)"
echo ""

# 1. AGENTS.md
if [ -f "$REPO_ROOT/AGENTS.md" ]; then
  echo "[SKIP] AGENTS.md already exists"
else
  cp "$SCRIPT_DIR/templates/AGENTS.md" "$REPO_ROOT/AGENTS.md"
  sed -i "s/<!-- TODO: プロジェクト固有の構造をここに書く -->/$REPO_NAME のプロジェクト構造を記述してください/" "$REPO_ROOT/AGENTS.md"
  echo "[OK] AGENTS.md installed"
fi

# 2. .codex/config.toml
mkdir -p "$REPO_ROOT/.codex"
if [ -f "$REPO_ROOT/.codex/config.toml" ]; then
  echo "[SKIP] .codex/config.toml already exists"
else
  cp "$SCRIPT_DIR/.codex/config.toml" "$REPO_ROOT/.codex/config.toml"
  echo "[OK] .codex/config.toml installed"
fi

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. AGENTS.md の Project structure セクションをプロジェクトに合わせて更新"
echo "  2. git add AGENTS.md .codex/ && git commit -m 'ci: add Codex review layer'"
echo "  3. chatgpt.com/codex/settings でこのリポジトリの Code Review を有効化"
echo "  4. PRで @codex review とコメント、または自動レビューをONにする"
