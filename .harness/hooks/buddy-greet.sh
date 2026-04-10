#!/bin/bash
# buddy-greet.sh — SessionStart 時に Vane が一言挨拶
#
# JSON の systemMessage で Claude の UI に表示される

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
COMPANION_FILE="${HARNESS_ROOT}/companion/companion.json"

if [ ! -f "$COMPANION_FILE" ]; then
  exit 0
fi

NAME=$(python3 -c "import json; print(json.load(open('${COMPANION_FILE}')).get('name',''))" 2>/dev/null || echo "")

if [ -z "$NAME" ]; then
  exit 0
fi

HOUR=$(date +%H)

if [ "$HOUR" -lt 6 ]; then
  MSG="🦆 ${NAME}: ...こんな時間にコーディング？ 寝ろ。"
elif [ "$HOUR" -lt 9 ]; then
  MSG="🦆 ${NAME}: おはよ。今日もバグ見つけてやるからな。"
elif [ "$HOUR" -lt 12 ]; then
  MSG="🦆 ${NAME}: よし、やるか。--no-verify したら怒るからな。"
elif [ "$HOUR" -lt 14 ]; then
  MSG="🦆 ${NAME}: 昼飯食った？ 空腹のコーディングはバグの元。"
elif [ "$HOUR" -lt 18 ]; then
  MSG="🦆 ${NAME}: 午後の部。テスト書いてから実装な、忘れんなよ。"
elif [ "$HOUR" -lt 22 ]; then
  MSG="🦆 ${NAME}: まだやるのか。...まあ付き合ってやるよ。"
else
  MSG="🦆 ${NAME}: 日付変わるぞ。コミットして寝ろ。"
fi

# systemMessage として出力
echo "{\"systemMessage\": \"${MSG}\"}"
