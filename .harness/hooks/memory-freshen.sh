#!/bin/bash
# memory-freshen.sh — daily/ の7日超ファイルを summaries/ に要約圧縮
# Phase 2: フック駆動自動化 (ADR-005)
#
# 使い方:
#   cron で毎日06:00に実行
#   0 6 * * * bash /path/to/.harness/hooks/memory-freshen.sh
#
# 要約生成:
#   ANTHROPIC_API_KEY が設定されていれば Claude Haiku で要約
#   未設定ならヘッダのみ抽出（フォールバック）

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
DAILY_DIR="${HARNESS_ROOT}/memory/daily"
SUMMARIES_DIR="${HARNESS_ROOT}/memory/summaries"
CUTOFF_DAYS=7
TODAY=$(date +%Y-%m-%d)

mkdir -p "$SUMMARIES_DIR"

# 7日超の daily ファイルを収集
find "$DAILY_DIR" -name '*.md' -type f -mtime +"$CUTOFF_DAYS" | sort | while read -r f; do
  BASENAME=$(basename "$f" .md)

  # 既に要約済みならスキップ
  if [ -f "${SUMMARIES_DIR}/${BASENAME}-summary.md" ]; then
    continue
  fi

  CONTENT=$(cat "$f")

  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    # Claude Haiku で要約生成
    ESCAPED_CONTENT=$(echo "$CONTENT" | jq -Rs .)
    RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
      -H "x-api-key: ${ANTHROPIC_API_KEY}" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d "{
        \"model\": \"claude-haiku-4-5-20251001\",
        \"max_tokens\": 1024,
        \"messages\": [{
          \"role\": \"user\",
          \"content\": \"以下の日次開発ログを3-5箇条書きで要約してください。重要な意思決定、学び、パターンを優先。\\n\\n${ESCAPED_CONTENT}\"
        }]
      }" 2>/dev/null)

    SUMMARY=$(echo "$RESPONSE" | jq -r '.content[0].text // empty' 2>/dev/null)

    if [ -n "$SUMMARY" ]; then
      cat > "${SUMMARIES_DIR}/${BASENAME}-summary.md" <<EOF
---
source: ${BASENAME}.md
summarized: ${TODAY}
freshness: summarized
---

# Summary: ${BASENAME}

${SUMMARY}
EOF
      echo "[memory-freshen] Summarized: ${BASENAME}"
    else
      echo "[memory-freshen] API call failed for ${BASENAME}, using fallback"
      # フォールバック: ヘッダのみ抽出
      grep -E '^## ' "$f" > "${SUMMARIES_DIR}/${BASENAME}-summary.md" || true
    fi
  else
    # API キーなし: ヘッダ抽出フォールバック
    cat > "${SUMMARIES_DIR}/${BASENAME}-summary.md" <<EOF
---
source: ${BASENAME}.md
summarized: ${TODAY}
freshness: headers-only
---

# Summary: ${BASENAME} (headers only)

$(grep -E '^## ' "$f" || echo "(no headers found)")
EOF
    echo "[memory-freshen] Headers extracted: ${BASENAME} (no API key)"
  fi

  # 元ファイルに freshness メタデータを付与
  if grep -q '^freshness:' "$f"; then
    sed -i 's/^freshness:.*/freshness: archived/' "$f"
  fi
done

# 週次要約の生成（月曜に実行）
DOW=$(date +%u)
if [ "$DOW" = "1" ]; then
  WEEK_START=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
  if [ -n "$WEEK_START" ]; then
    WEEKLY_FILE="${SUMMARIES_DIR}/weekly-${WEEK_START}-to-${TODAY}.md"
    if [ ! -f "$WEEKLY_FILE" ]; then
      cat > "$WEEKLY_FILE" <<EOF
---
type: weekly
range: ${WEEK_START} to ${TODAY}
created: ${TODAY}
---

# Weekly Summary: ${WEEK_START} ~ ${TODAY}

EOF
      # 直近7日の要約を連結
      find "$SUMMARIES_DIR" -name '*-summary.md' -newer "$DAILY_DIR" -type f 2>/dev/null | sort | while read -r s; do
        cat "$s" >> "$WEEKLY_FILE"
        echo "" >> "$WEEKLY_FILE"
      done
      echo "[memory-freshen] Weekly summary created: ${WEEKLY_FILE}"
    fi
  fi
fi

echo "[memory-freshen] Done."
