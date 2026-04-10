#!/bin/bash
# buddy-status.sh — statusLine 用。Vane の状態を1行で出力
#
# statusLine は短い文字列を期待するので、名前 + 気分を出す

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
COMPANION_FILE="${HARNESS_ROOT}/companion/companion.json"

if [ ! -f "$COMPANION_FILE" ]; then
  echo ""
  exit 0
fi

NAME=$(python3 -c "import json; print(json.load(open('${COMPANION_FILE}')).get('name',''))" 2>/dev/null || echo "")

if [ -z "$NAME" ]; then
  echo ""
  exit 0
fi

# 時間帯で気分を変える
HOUR=$(date +%H)
if [ "$HOUR" -lt 6 ]; then
  MOOD="😴 zzz..."
elif [ "$HOUR" -lt 9 ]; then
  MOOD="🥱 おはよ..."
elif [ "$HOUR" -lt 12 ]; then
  MOOD="🦆 調子いいよ"
elif [ "$HOUR" -lt 14 ]; then
  MOOD="🍙 腹減った"
elif [ "$HOUR" -lt 18 ]; then
  MOOD="👀 コード見てる"
elif [ "$HOUR" -lt 22 ]; then
  MOOD="🌙 そろそろ休む？"
else
  MOOD="😤 まだやるの？"
fi

echo "${NAME} ${MOOD}"
