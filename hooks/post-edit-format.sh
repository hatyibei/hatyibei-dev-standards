#!/bin/bash
# ファイル編集後の自動フォーマット
# フック駆動自動化 (ADR-005) に基づく

# $TOOL_INPUT にファイルパスが含まれる想定
FILE_PATH="${TOOL_INPUT:-}"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# ファイル拡張子に応じたフォーマッター実行
case "$FILE_PATH" in
  *.js|*.ts|*.jsx|*.tsx|*.json|*.css|*.md)
    if command -v npx > /dev/null 2>&1; then
      npx prettier --write "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  *.py)
    if command -v black > /dev/null 2>&1; then
      black --quiet "$FILE_PATH" 2>/dev/null || true
    elif command -v ruff > /dev/null 2>&1; then
      ruff format "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  *.go)
    if command -v gofmt > /dev/null 2>&1; then
      gofmt -w "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  *.rs)
    if command -v rustfmt > /dev/null 2>&1; then
      rustfmt "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

# 常に成功
exit 0
