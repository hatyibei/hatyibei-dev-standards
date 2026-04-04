#!/bin/bash
# セッション停止時の要約
# フック駆動自動化 (ADR-005) + 永続メモリシステム (ADR-003) に基づく

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Git変更のサマリーを出力
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "=== Session Summary ==="

  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  echo "Branch: ${BRANCH}"

  # セッション中のコミット数（直近1時間）
  RECENT_COMMITS=$(git log --since="1 hour ago" --oneline 2>/dev/null | wc -l)
  echo "Recent commits: ${RECENT_COMMITS}"

  # 未コミットの変更
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
  echo "Uncommitted changes: ${UNCOMMITTED}"

  if [ "$UNCOMMITTED" -gt 0 ]; then
    echo ""
    echo "Changed files:"
    git status --porcelain 2>/dev/null | head -20
  fi

  echo "=== End Summary ==="
fi

exit 0
