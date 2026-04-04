#!/bin/bash
# Bashコマンド実行前の安全性チェック
# フック駆動自動化 (ADR-005) に基づく

# $TOOL_INPUT にコマンド内容が渡される想定
COMMAND="${TOOL_INPUT:-}"

# 危険なパターンの検出（警告のみ、ブロックしない）
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "git push.*--force.*main"
  "git push.*--force.*master"
  "git reset --hard"
  "DROP TABLE"
  "DROP DATABASE"
  "--no-verify"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qi "$pattern"; then
    echo "WARNING: Potentially dangerous command detected: $pattern" >&2
    echo "Please confirm before proceeding." >&2
  fi
done

# 常に成功（グレースフルデグラデーション）
exit 0
