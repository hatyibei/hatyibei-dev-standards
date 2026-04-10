#!/bin/bash
# buddy-greet.sh — claude CLI (Haiku) でVaneのセリフを生成
# SessionStart/Stop フックから呼ばれる

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

if [ "$MODE" = "start" ]; then
  CONTEXT="セッション開始。現在${HOUR}時。挨拶して。"
else
  CONTEXT="セッション終了。現在${HOUR}時。労うか寝ろと言って。"
fi

# claude CLI で生成
if command -v claude > /dev/null 2>&1; then
  MSG=$(claude -p --model haiku "あなたは${NAME}というアヒルのコンパニオン。性格: ${PERSONALITY}。日本語で20文字以内の一言だけ返せ。絵文字は🦆だけ使っていい。セリフだけ返せ、説明不要。${CONTEXT}" 2>/dev/null | head -1)

  if [ -n "$MSG" ]; then
    echo "{\"systemMessage\": \"🦆 ${MSG}\"}"
    exit 0
  fi
fi

# フォールバック
if [ "$MODE" = "start" ]; then
  if [ "$HOUR" -lt 6 ]; then MSG="${NAME}: ...こんな時間に？寝ろ。"
  elif [ "$HOUR" -lt 9 ]; then MSG="${NAME}: おはよ。バグ見つけてやるよ。"
  elif [ "$HOUR" -lt 12 ]; then MSG="${NAME}: --no-verifyしたら怒るからな。"
  elif [ "$HOUR" -lt 18 ]; then MSG="${NAME}: テスト先に書けよ。"
  else MSG="${NAME}: まだやるのか。付き合うけど。"
  fi
else
  if [ "$HOUR" -lt 6 ]; then MSG="${NAME}: やっと寝るのか。おやすみ。"
  elif [ "$HOUR" -lt 18 ]; then MSG="${NAME}: おつかれ。まあまあだったな。"
  else MSG="${NAME}: 今日はここまで。また明日な。"
  fi
fi

echo "{\"systemMessage\": \"🦆 ${MSG}\"}"
