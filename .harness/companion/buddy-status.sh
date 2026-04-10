#!/bin/bash
# buddy-status.sh — statusLine 用。claude CLI (Haiku) でVaneの気分を生成
# 5分キャッシュで呼び出し回数を抑制

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
COMPANION_FILE="${HARNESS_ROOT}/companion/companion.json"
CACHE_FILE="/tmp/vane-status-cache"
CACHE_TTL=300  # 5分

if [ ! -f "$COMPANION_FILE" ]; then
  echo ""
  exit 0
fi

NAME=$(python3 -c "import json; print(json.load(open('${COMPANION_FILE}')).get('name',''))" 2>/dev/null || echo "")

if [ -z "$NAME" ]; then
  echo ""
  exit 0
fi

# キャッシュが有効ならそれを返す
if [ -f "$CACHE_FILE" ]; then
  CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$CACHE_AGE" -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

HOUR=$(date +%H)

# claude CLI で生成
if command -v claude > /dev/null 2>&1; then
  MOOD=$(claude -p --model haiku "あなたは${NAME}というアヒル。皮肉屋で愛情深い。現在${HOUR}時。今の気分を絵文字1つ+8文字以内で返せ。セリフだけ。" 2>/dev/null | head -1)

  if [ -n "$MOOD" ]; then
    RESULT="${NAME} ${MOOD}"
    echo "$RESULT" > "$CACHE_FILE"
    echo "$RESULT"
    exit 0
  fi
fi

# フォールバック
if [ "$HOUR" -lt 6 ]; then MOOD="😴 zzz..."
elif [ "$HOUR" -lt 9 ]; then MOOD="🥱 おはよ..."
elif [ "$HOUR" -lt 12 ]; then MOOD="🦆 調子いいよ"
elif [ "$HOUR" -lt 14 ]; then MOOD="🍙 腹減った"
elif [ "$HOUR" -lt 18 ]; then MOOD="👀 コード見てる"
elif [ "$HOUR" -lt 22 ]; then MOOD="🌙 そろそろ休む？"
else MOOD="😤 まだやるの？"
fi

RESULT="${NAME} ${MOOD}"
echo "$RESULT" > "$CACHE_FILE"
echo "$RESULT"
