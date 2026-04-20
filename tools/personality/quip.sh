#!/bin/bash
# quip.sh — Vane の文脈依存コメントを stdout に 1 行出す
#
# 使い方:
#   bash tools/personality/quip.sh success
#   bash tools/personality/quip.sh fail
#   bash tools/personality/quip.sh review-p0
#   bash tools/personality/quip.sh review-p1
#   bash tools/personality/quip.sh review-p2
#   bash tools/personality/quip.sh idle
#
# データソース:
#   agent/personality/quips/on-*.md の番号付き行 ("1. コメント")
#   agent/personality/traits.yml
#
# 依存: awk, shuf (or bash $RANDOM フォールバック)

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
QUIPS_DIR="${REPO_ROOT}/agent/personality/quips"

CONTEXT="${1:-idle}"

case "$CONTEXT" in
  success)          FILE="${QUIPS_DIR}/on-success.md" ;;
  fail|failure)     FILE="${QUIPS_DIR}/on-fail.md" ;;
  review-p0|p0)     FILE="${QUIPS_DIR}/on-review.md"; SECTION="P0" ;;
  review-p1|p1)     FILE="${QUIPS_DIR}/on-review.md"; SECTION="P1" ;;
  review-p2|p2)     FILE="${QUIPS_DIR}/on-review.md"; SECTION="P2" ;;
  review)           FILE="${QUIPS_DIR}/on-review.md" ;;
  idle)
    # idle はまだ定型ファイル無し → 時間帯で合成
    HOUR=$(date +%H)
    if [ "$HOUR" -lt 6 ]; then echo "🦆 …寝ないの？"
    elif [ "$HOUR" -lt 12 ]; then echo "🦆 おはよ、今日は何やる？"
    elif [ "$HOUR" -lt 18 ]; then echo "🦆 集中してるね、邪魔しない。"
    else echo "🦆 そろそろコミットしておこう。"
    fi
    exit 0
    ;;
  -h|--help)
    grep -E '^# ' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  *)
    echo "unknown context: $CONTEXT" >&2
    echo "Usage: $0 {success|fail|review-p0|review-p1|review-p2|review|idle}" >&2
    exit 1
    ;;
esac

if [ ! -f "$FILE" ]; then
  echo "[quip] ERROR: $FILE not found." >&2
  exit 1
fi

# 番号付き行を抽出 (特定セクション or 全体)
if [ -n "${SECTION:-}" ]; then
  # ## P0 / ## P1 / ## P2 セクション内の番号付き行のみ
  quips=$(awk -v sect="$SECTION" '
    /^## P0/ { current = "P0"; next }
    /^## P1/ { current = "P1"; next }
    /^## P2/ { current = "P2"; next }
    /^## /   { current = ""; next }
    current == sect && /^[0-9]+\. / {
      sub(/^[0-9]+\. /, "")
      print
    }
  ' "$FILE")
else
  quips=$(awk '/^[0-9]+\. / { sub(/^[0-9]+\. /, ""); print }' "$FILE")
fi

if [ -z "$quips" ]; then
  echo "[quip] WARN: no quips found for context=$CONTEXT" >&2
  exit 0
fi

# ランダム 1 行
if command -v shuf >/dev/null 2>&1; then
  echo "$quips" | shuf -n 1
else
  # フォールバック: $RANDOM
  mapfile -t arr < <(echo "$quips")
  idx=$(( RANDOM % ${#arr[@]} ))
  echo "${arr[$idx]}"
fi
