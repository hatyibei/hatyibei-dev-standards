#!/bin/bash
# post-session.sh — セッション終了時に inbox/ → daily/ へ転記
# Phase 2: フック駆動自動化 (ADR-005) + 永続メモリ (ADR-003)
#
# 使い方:
#   SessionEnd フックから呼び出す、またはセッション終了時に手動実行
#   bash .harness/hooks/post-session.sh

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
INBOX_DIR="${HARNESS_ROOT}/memory/inbox"
DAILY_DIR="${HARNESS_ROOT}/memory/daily"
TODAY=$(date +%Y-%m-%d)
DAILY_FILE="${DAILY_DIR}/${TODAY}.md"

# inbox/ が空なら何もしない
if [ -z "$(find "$INBOX_DIR" -name '*.md' -type f 2>/dev/null)" ]; then
  echo "[post-session] inbox/ is empty. Nothing to flush."
  exit 0
fi

# daily/ のファイルがなければヘッダ付きで作成
if [ ! -f "$DAILY_FILE" ]; then
  cat > "$DAILY_FILE" <<EOF
---
date: ${TODAY}
freshness: fresh
---

# Daily Log: ${TODAY}

EOF
fi

# inbox/ の各ファイルを daily/ に追記
for f in "${INBOX_DIR}"/*.md; do
  [ -f "$f" ] || continue
  echo "" >> "$DAILY_FILE"
  echo "---" >> "$DAILY_FILE"
  echo "" >> "$DAILY_FILE"
  # ファイル名をセクションタイトルに
  BASENAME=$(basename "$f" .md)
  TIMESTAMP=$(date +%H:%M)
  echo "## ${TIMESTAMP} — ${BASENAME}" >> "$DAILY_FILE"
  echo "" >> "$DAILY_FILE"
  cat "$f" >> "$DAILY_FILE"
  # inbox から削除
  rm "$f"
done

echo "[post-session] Flushed inbox/ → ${DAILY_FILE}"
