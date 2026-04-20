#!/bin/bash
# claude-api.sh — Anthropic API 呼び出しの共用ライブラリ
#
# 使い方:
#   source tools/lib/claude-api.sh
#   response=$(call_claude "$HAIKU_MODEL" "$prompt")
#   text=$(extract_text "$response")
#   json=$(extract_json "$text")
#
# 環境変数:
#   ANTHROPIC_API_KEY  必須
#   CLAUDE_API_MAX_TOKENS  デフォルト 1024
#
# 提供モデル定数:
#   HAIKU_MODEL        claude-haiku-4-5-20251001
#   OPUS_MODEL         claude-opus-4-6-20250422
#
# 後方互換: .harness/hooks/memory-router.sh がこれを source する。

: "${HAIKU_MODEL:=claude-haiku-4-5-20251001}"
: "${OPUS_MODEL:=claude-opus-4-6-20250422}"
: "${CLAUDE_API_MAX_TOKENS:=1024}"

call_claude() {
  local model="$1"
  local prompt="$2"
  local max_tokens="${3:-$CLAUDE_API_MAX_TOKENS}"

  if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo '{"error":{"type":"missing_api_key","message":"ANTHROPIC_API_KEY is not set"}}' >&2
    return 1
  fi

  local escaped_prompt
  escaped_prompt=$(printf '%s' "$prompt" | jq -Rs .)

  curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
      \"model\": \"${model}\",
      \"max_tokens\": ${max_tokens},
      \"messages\": [{
        \"role\": \"user\",
        \"content\": ${escaped_prompt}
      }]
    }" 2>/dev/null
}

extract_text() {
  local response="$1"
  echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null
}

extract_json() {
  local text="$1"
  echo "$text" | grep -oP '\{[^{}]*(\{[^{}]*\}[^{}]*)*\}' | head -1 2>/dev/null || echo ""
}
