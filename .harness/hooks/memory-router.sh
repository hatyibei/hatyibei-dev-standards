#!/bin/bash
# memory-router.sh — inbox/ を監視し Haiku で分類、confidence 低ければ Opus にエスカレーション
# Phase 5: Haiku→Opus ルーティング
#
# 使い方:
#   # ワンショット（inbox/ の未分類ファイルを処理）
#   bash .harness/hooks/memory-router.sh
#
#   # 監視モード（10分ごとにポーリング）
#   bash .harness/hooks/memory-router.sh watch
#
# 環境変数:
#   ANTHROPIC_API_KEY  必須
#   ROUTER_INTERVAL    監視間隔（秒、デフォルト600）
#   CONFIDENCE_THRESHOLD  Opusエスカレーション閾値（デフォルト0.7）

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
INBOX_DIR="${HARNESS_ROOT}/memory/inbox"
DOMAINS_DIR="${HARNESS_ROOT}/memory/domains"
DAILY_DIR="${HARNESS_ROOT}/memory/daily"
MODE="${1:-once}"
ROUTER_INTERVAL="${ROUTER_INTERVAL:-600}"
CONFIDENCE_THRESHOLD="${CONFIDENCE_THRESHOLD:-0.7}"
TODAY=$(date +%Y-%m-%d)

HAIKU_MODEL="claude-haiku-4-5-20251001"
OPUS_MODEL="claude-opus-4-6-20250422"

# --- API呼び出し ---

call_claude() {
  local model="$1"
  local prompt="$2"

  local escaped_prompt
  escaped_prompt=$(echo "$prompt" | jq -Rs .)

  curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
      \"model\": \"${model}\",
      \"max_tokens\": 512,
      \"messages\": [{
        \"role\": \"user\",
        \"content\": ${escaped_prompt}
      }]
    }" 2>/dev/null
}

# --- 分類プロンプト ---

build_classification_prompt() {
  local content="$1"
  local escaped_content
  escaped_content=$(echo "$content" | head -100)  # 先頭100行に制限

  cat <<EOF
以下の開発ログエントリを分類してください。

## 分類ルール

### domain (必須、1つ選択)
- dev: 技術パターン、コード、アーキテクチャ、ツール、デバッグ
- product: プロダクト固有の機能、UI/UX、ユーザーストーリー
- biz: ビジネス、組織、戦略、契約、人事

### importance (必須、数値)
基礎: 1.0
- 意思決定（decided, chose, rejected）: +0.5
- アーキテクチャ関連: +0.3
- セキュリティ関連: +0.3
- エラー・修正関連: +0.2
- パフォーマンス関連: +0.2
- コスト関連: +0.2

### confidence (必須、0.0-1.0)
分類の確信度。0.7未満は「判断が難しい」。

## 出力形式（JSON のみ、説明不要）
{"domain":"dev|product|biz","importance":1.0,"confidence":0.8,"summary":"1行要約"}

## エントリ
${escaped_content}
EOF
}

# --- 1ファイルの処理 ---

process_file() {
  local file="$1"
  local basename
  basename=$(basename "$file" .md)
  local content
  content=$(cat "$file")

  echo "[memory-router] Processing: ${basename}"

  # Step 1: Haiku で分類
  local prompt
  prompt=$(build_classification_prompt "$content")
  local response
  response=$(call_claude "$HAIKU_MODEL" "$prompt")
  local result
  result=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)

  if [ -z "$result" ]; then
    echo "[memory-router] ERROR: API call failed for ${basename}. Skipping."
    return 1
  fi

  # JSON を抽出（テキスト中に埋まっている場合に対応）
  local json
  json=$(echo "$result" | grep -oP '\{[^}]+\}' | head -1 2>/dev/null || echo "")

  if [ -z "$json" ]; then
    echo "[memory-router] ERROR: Could not parse response for ${basename}. Raw: ${result}"
    return 1
  fi

  local domain importance confidence summary
  domain=$(echo "$json" | jq -r '.domain // "dev"' 2>/dev/null)
  importance=$(echo "$json" | jq -r '.importance // 1.0' 2>/dev/null)
  confidence=$(echo "$json" | jq -r '.confidence // 0.5' 2>/dev/null)
  summary=$(echo "$json" | jq -r '.summary // ""' 2>/dev/null)

  # Step 2: confidence チェック → 低ければ Opus にエスカレーション
  local needs_escalation
  needs_escalation=$(echo "$confidence < $CONFIDENCE_THRESHOLD" | bc 2>/dev/null || echo "0")

  if [ "$needs_escalation" = "1" ]; then
    echo "[memory-router] Low confidence (${confidence}). Escalating to Opus..."

    local opus_response
    opus_response=$(call_claude "$OPUS_MODEL" "$prompt")
    local opus_result
    opus_result=$(echo "$opus_response" | jq -r '.content[0].text // empty' 2>/dev/null)

    if [ -n "$opus_result" ]; then
      local opus_json
      opus_json=$(echo "$opus_result" | grep -oP '\{[^}]+\}' | head -1 2>/dev/null || echo "")

      if [ -n "$opus_json" ]; then
        domain=$(echo "$opus_json" | jq -r '.domain // "dev"' 2>/dev/null)
        importance=$(echo "$opus_json" | jq -r '.importance // 1.0' 2>/dev/null)
        confidence=$(echo "$opus_json" | jq -r '.confidence // 0.5' 2>/dev/null)
        summary=$(echo "$opus_json" | jq -r '.summary // ""' 2>/dev/null)
        echo "[memory-router] Opus classified: domain=${domain}, importance=${importance}, confidence=${confidence}"
      fi
    fi
  fi

  # Step 3: domain ディレクトリに分類結果を保存
  local domain_dir="${DOMAINS_DIR}/${domain}"
  mkdir -p "$domain_dir"

  local target_file="${domain_dir}/learnings.md"

  # learnings.md がなければ作成
  if [ ! -f "$target_file" ]; then
    cat > "$target_file" <<EOF
---
domain: ${domain}
updated: ${TODAY}
---

# ${domain} — Learnings

EOF
  fi

  # エントリを追記
  cat >> "$target_file" <<EOF

---

### ${TODAY} — ${basename}
> importance: ${importance} | confidence: ${confidence}

${summary}

<details>
<summary>原文</summary>

${content}

</details>

EOF

  # learnings.md の updated を更新
  sed -i "s/^updated:.*/updated: ${TODAY}/" "$target_file"

  echo "[memory-router] Classified: ${basename} → ${domain}/ (importance: ${importance}, confidence: ${confidence})"

  # Step 4: inbox から削除（daily/ への転記は post-session.sh の役割）
  # ここでは分類済みマーカーを付与
  mv "$file" "${file%.md}.classified.md"
}

# --- メイン ---

do_once() {
  if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[memory-router] ERROR: ANTHROPIC_API_KEY is not set. Cannot route."
    echo "[memory-router] Set it with: export ANTHROPIC_API_KEY=sk-ant-..."
    exit 1
  fi

  local processed=0
  for f in "${INBOX_DIR}"/*.md; do
    [ -f "$f" ] || continue
    # .classified.md は処理済みなのでスキップ
    case "$f" in *.classified.md) continue ;; esac
    process_file "$f" && processed=$((processed + 1)) || true
  done

  if [ "$processed" -eq 0 ]; then
    echo "[memory-router] No unclassified files in inbox/."
  else
    echo "[memory-router] Processed ${processed} file(s)."
  fi
}

do_watch() {
  echo "[memory-router] Watching inbox/ every ${ROUTER_INTERVAL}s (Ctrl+C to stop)"
  while true; do
    do_once
    sleep "$ROUTER_INTERVAL"
  done
}

case "$MODE" in
  once)
    do_once
    ;;
  watch)
    do_watch
    ;;
  *)
    echo "Usage: $0 {once|watch}"
    exit 1
    ;;
esac
