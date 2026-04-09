#!/bin/bash
# memory-score.sh — daily/ エントリに importance スコアを付与・減衰
# Phase 4: importance スコアリング
#
# 使い方:
#   post-session.sh の後に実行（新規エントリにスコア付与）
#   memory-freshen.sh の前に実行（全エントリの日次減衰）
#
#   # 新規エントリのスコアリング
#   bash .harness/hooks/memory-score.sh score
#
#   # 全エントリの日次減衰
#   bash .harness/hooks/memory-score.sh decay
#
#   # 両方（cron推奨）
#   bash .harness/hooks/memory-score.sh all
#
# cron:
#   5 6 * * * bash /path/to/.harness/hooks/memory-score.sh all

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
DAILY_DIR="${HARNESS_ROOT}/memory/daily"
DECAY_RATE="0.95"
MODE="${1:-all}"

# --- ヘルパー関数 ---

# YAML frontmatter から importance を読む（なければ空文字）
get_importance() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | grep '^importance:' | head -1 | awk '{print $2}'
}

# YAML frontmatter が存在するか
has_frontmatter() {
  local file="$1"
  head -1 "$file" 2>/dev/null | grep -q '^---$'
}

# キーワードベースの importance 算出
calculate_importance() {
  local file="$1"
  local content
  content=$(cat "$file")

  # 基礎スコア
  local score="1.0"

  # 意思決定キーワード: +0.5
  if echo "$content" | grep -qiE '(decided|chose|rejected|選択|決定|判断|採用|却下|方針)'; then
    score=$(echo "$score + 0.5" | bc)
  fi

  # アーキテクチャ関連: +0.3
  if echo "$content" | grep -qiE '(architect|アーキテクチャ|設計|ADR|migration|マイグレーション|schema|スキーマ)'; then
    score=$(echo "$score + 0.3" | bc)
  fi

  # セキュリティ関連: +0.3
  if echo "$content" | grep -qiE '(security|セキュリティ|vulnerability|脆弱性|CVE|OWASP|auth|認証|XSS|injection)'; then
    score=$(echo "$score + 0.3" | bc)
  fi

  # エラー・修正関連: +0.2
  if echo "$content" | grep -qiE '(error|bug|fix|修正|バグ|障害|incident|hotfix|regression|リグレッション)'; then
    score=$(echo "$score + 0.2" | bc)
  fi

  # パフォーマンス関連: +0.2
  if echo "$content" | grep -qiE '(performance|パフォーマンス|latency|レイテンシ|cache|キャッシュ|optimize|最適化)'; then
    score=$(echo "$score + 0.2" | bc)
  fi

  # コスト関連: +0.2
  if echo "$content" | grep -qiE '(cost|コスト|pricing|料金|budget|予算|billing|課金)'; then
    score=$(echo "$score + 0.2" | bc)
  fi

  echo "$score"
}

# frontmatter の importance を更新（なければ追加）
update_importance() {
  local file="$1"
  local new_score="$2"

  if ! has_frontmatter "$file"; then
    # frontmatter がない場合は追加
    local date_str
    date_str=$(basename "$file" .md)
    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile" <<EOF
---
date: ${date_str}
importance: ${new_score}
freshness: fresh
---

EOF
    cat "$file" >> "$tmpfile"
    mv "$tmpfile" "$file"
  elif grep -q '^importance:' "$file"; then
    # 既存の importance を更新
    sed -i "s/^importance:.*/importance: ${new_score}/" "$file"
  else
    # frontmatter はあるが importance がない場合は追加
    sed -i "/^---$/a importance: ${new_score}" "$file"
    # 2番目の --- の前ではなく、最初の --- の後に追加されるので問題なし
  fi
}

# --- メイン処理 ---

# スコアリング: frontmatter に importance がないファイルにスコアを付与
do_score() {
  echo "[memory-score] Scoring unscored entries..."
  local scored=0

  find "$DAILY_DIR" -name '*.md' -type f | while read -r f; do
    local current_importance
    current_importance=$(get_importance "$f")

    # 既にスコア付きならスキップ
    if [ -n "$current_importance" ]; then
      continue
    fi

    local new_score
    new_score=$(calculate_importance "$f")
    update_importance "$f" "$new_score"
    scored=$((scored + 1))
    echo "[memory-score] Scored: $(basename "$f") → importance: ${new_score}"
  done

  echo "[memory-score] Scoring done."
}

# 減衰: 全エントリの importance を ×0.95
do_decay() {
  echo "[memory-score] Applying daily decay (×${DECAY_RATE})..."
  local decayed=0

  find "$DAILY_DIR" -name '*.md' -type f | while read -r f; do
    local current_importance
    current_importance=$(get_importance "$f")

    # importance がないファイルはスキップ
    if [ -z "$current_importance" ]; then
      continue
    fi

    # 減衰適用
    local new_score
    new_score=$(echo "$current_importance * $DECAY_RATE" | bc 2>/dev/null || echo "$current_importance")

    # 0.1 未満は切り捨て（ノイズ除去）
    local is_negligible
    is_negligible=$(echo "$new_score < 0.1" | bc 2>/dev/null || echo "0")
    if [ "$is_negligible" = "1" ]; then
      new_score="0.0"
    fi

    update_importance "$f" "$new_score"
    decayed=$((decayed + 1))
  done

  echo "[memory-score] Decay done."
}

# summaries/ のスコアも減衰
do_decay_summaries() {
  local SUMMARIES_DIR="${HARNESS_ROOT}/memory/summaries"
  find "$SUMMARIES_DIR" -name '*.md' -type f 2>/dev/null | while read -r f; do
    local current_importance
    current_importance=$(get_importance "$f")
    if [ -z "$current_importance" ]; then
      continue
    fi
    local new_score
    new_score=$(echo "$current_importance * $DECAY_RATE" | bc 2>/dev/null || echo "$current_importance")
    local is_negligible
    is_negligible=$(echo "$new_score < 0.1" | bc 2>/dev/null || echo "0")
    if [ "$is_negligible" = "1" ]; then
      new_score="0.0"
    fi
    update_importance "$f" "$new_score"
  done
}

case "$MODE" in
  score)
    do_score
    ;;
  decay)
    do_decay
    do_decay_summaries
    ;;
  all)
    do_score
    do_decay
    do_decay_summaries
    ;;
  *)
    echo "Usage: $0 {score|decay|all}"
    exit 1
    ;;
esac

echo "[memory-score] All done."
