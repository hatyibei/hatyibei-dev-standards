#!/bin/bash
# memory-compost.sh — summaries/ の90日超ファイルを compost/ に移動
# Phase 2: フック駆動自動化 (ADR-005)
#
# 使い方:
#   cron で90日ごと、または月初に実行
#   0 6 1 */3 * bash /path/to/.harness/hooks/memory-compost.sh

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
SUMMARIES_DIR="${HARNESS_ROOT}/memory/summaries"
COMPOST_DIR="${HARNESS_ROOT}/memory/compost"
CUTOFF_DAYS=90

mkdir -p "$COMPOST_DIR"

MOVED=0

# summaries/ の90日超ファイルを compost/ に移動
find "$SUMMARIES_DIR" -name '*.md' -type f -mtime +"$CUTOFF_DAYS" | while read -r f; do
  BASENAME=$(basename "$f")
  mv "$f" "${COMPOST_DIR}/${BASENAME}"
  MOVED=$((MOVED + 1))
  echo "[memory-compost] Composted: ${BASENAME}"
done

# daily/ の90日超で既に要約済みのファイルも compost へ
DAILY_DIR="${HARNESS_ROOT}/memory/daily"
find "$DAILY_DIR" -name '*.md' -type f -mtime +"$CUTOFF_DAYS" | while read -r f; do
  BASENAME=$(basename "$f" .md)
  # 要約が存在する場合のみ compost（要約がなければ保持）
  if [ -f "${SUMMARIES_DIR}/${BASENAME}-summary.md" ] || [ -f "${COMPOST_DIR}/${BASENAME}-summary.md" ]; then
    mv "$f" "${COMPOST_DIR}/${BASENAME}-daily.md"
    echo "[memory-compost] Composted daily: ${BASENAME}"
  fi
done

# compost/ の365日超は完全削除
find "$COMPOST_DIR" -name '*.md' -type f -mtime +365 | while read -r f; do
  BASENAME=$(basename "$f")
  rm "$f"
  echo "[memory-compost] Permanently deleted: ${BASENAME}"
done

echo "[memory-compost] Done."
