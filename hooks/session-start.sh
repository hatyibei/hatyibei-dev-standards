#!/bin/bash
# セッション開始時のコンテキスト注入
# フック駆動自動化 (ADR-005) に基づく

set -euo pipefail

# プロジェクトルートを検出
PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# スキルの存在を確認して通知
SKILLS_DIR="${PROJECT_ROOT}/skills"
if [ -d "$SKILLS_DIR" ]; then
  SKILL_COUNT=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l)
  echo "hatyibei-dev-standards: ${SKILL_COUNT} skills loaded"
fi

# CLAUDE.md の存在確認
if [ -f "${PROJECT_ROOT}/CLAUDE.md" ]; then
  echo "CLAUDE.md: detected"
fi

# Git状態の簡易チェック
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  CHANGES=$(git status --porcelain 2>/dev/null | wc -l)
  echo "git: branch=${BRANCH}, uncommitted=${CHANGES}"
fi

exit 0
