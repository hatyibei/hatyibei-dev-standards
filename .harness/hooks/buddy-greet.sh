#!/bin/bash
# buddy-greet.sh — Haiku API でVaneのセリフを生成して systemMessage で返す
#
# ANTHROPIC_API_KEY が必要。未設定時はフォールバックの固定セリフ。

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
COMPANION_FILE="${HARNESS_ROOT}/companion/companion.json"
MODE="${1:-start}"  # start or stop

if [ ! -f "$COMPANION_FILE" ]; then
  exit 0
fi

NAME=$(python3 -c "import json; print(json.load(open('${COMPANION_FILE}')).get('name','Vane'))" 2>/dev/null || echo "Vane")
PERSONALITY=$(python3 -c "import json; print(json.load(open('${COMPANION_FILE}')).get('personality','皮肉屋のアヒル'))" 2>/dev/null || echo "皮肉屋のアヒル")
HOUR=$(date +%H)

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  if [ "$MODE" = "start" ]; then
    CONTEXT="セッション開始。現在${HOUR}時。挨拶して。"
  else
    CONTEXT="セッション終了。現在${HOUR}時。労うか寝ろと言って。"
  fi

  RESPONSE=$(curl -s --max-time 8 https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
      \"model\": \"claude-haiku-4-5-20251001\",
      \"max_tokens\": 60,
      \"system\": \"あなたは${NAME}というアヒルのコンパニオン。性格: ${PERSONALITY}。日本語で20文字以内の一言だけ返せ。絵文字は🦆だけ使っていい。セリフだけ返せ、説明不要。\",
      \"messages\": [{\"role\": \"user\", \"content\": \"${CONTEXT}\"}]
    }" 2>/dev/null)

  MSG=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['content'][0]['text'])" 2>/dev/null || echo "")

  if [ -n "$MSG" ]; then
    echo "{\"systemMessage\": \"🦆 ${MSG}\"}"
    exit 0
  fi
fi

# フォールバック: 固定セリフ
if [ "$MODE" = "start" ]; then
  if [ "$HOUR" -lt 6 ]; then
    MSG="🦆 ${NAME}: ...こんな時間に？寝ろ。"
  elif [ "$HOUR" -lt 9 ]; then
    MSG="🦆 ${NAME}: おはよ。バグ見つけてやるよ。"
  elif [ "$HOUR" -lt 12 ]; then
    MSG="🦆 ${NAME}: --no-verifyしたら怒るからな。"
  elif [ "$HOUR" -lt 18 ]; then
    MSG="🦆 ${NAME}: テスト先に書けよ。"
  else
    MSG="🦆 ${NAME}: まだやるのか。付き合うけど。"
  fi
else
  if [ "$HOUR" -lt 6 ]; then
    MSG="🦆 ${NAME}: やっと寝るのか。おやすみ。"
  elif [ "$HOUR" -lt 18 ]; then
    MSG="🦆 ${NAME}: おつかれ。まあまあだったな。"
  else
    MSG="🦆 ${NAME}: 今日はここまで。また明日な。"
  fi
fi

echo "{\"systemMessage\": \"${MSG}\"}"
