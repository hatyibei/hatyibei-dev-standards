#!/bin/bash
# fts-build.sh — .harness/memory/{daily,summaries,domains}/**/*.md を SQLite FTS5 で索引化
#
# 使い方:
#   bash tools/search/fts-build.sh            # フルリビルド
#   bash tools/search/fts-build.sh --verbose  # 進捗を標準出力
#
# 依存: sqlite3, awk, jq
# 出力: .harness/memory/.index/memory.db (tear-down & rebuild)

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
MEMORY_DIR="${REPO_ROOT}/.harness/memory"
INDEX_DIR="${MEMORY_DIR}/.index"
DB="${INDEX_DIR}/memory.db"
SCHEMA="${REPO_ROOT}/tools/search/index.schema.sql"
VERBOSE="${1:-}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "[fts-build] ERROR: sqlite3 not found. Install with: apt-get install sqlite3 (or brew install sqlite)" >&2
  echo "[fts-build] Skipping. recall.sh will fall back to grep." >&2
  exit 2
fi

mkdir -p "$INDEX_DIR"
rm -f "$DB"
sqlite3 "$DB" < "$SCHEMA"

# YAML frontmatter を抽出 (先頭 --- ... --- 間)
extract_frontmatter() {
  awk '
    /^---$/ { fm++; next }
    fm == 1 { print }
    fm >= 2 { exit }
  ' "$1"
}

# frontmatter から key の値を取り出す (単純なやつだけ)
get_fm_value() {
  local file="$1" key="$2"
  extract_frontmatter "$file" | awk -F': *' -v k="$key" '$1 == k { print $2; exit }' | tr -d '"'
}

# 本文抽出 (frontmatter の後ろ)
extract_body() {
  awk '
    /^---$/ { fm++; if (fm == 2) { body = 1; next } }
    fm < 2 { next }
    body { print }
  ' "$1"
}

count=0
insert_entry() {
  local file="$1" layer="$2" domain="$3"
  local date importance freshness content

  date=$(get_fm_value "$file" "date")
  importance=$(get_fm_value "$file" "importance")
  freshness=$(get_fm_value "$file" "freshness")

  # frontmatter が無ければ全文
  if [ -z "$date" ] && [ -z "$importance" ]; then
    content=$(cat "$file")
  else
    content=$(extract_body "$file")
    [ -z "$content" ] && content=$(cat "$file")
  fi

  # ファイル名から日付を拾う (daily/YYYY-MM-DD.md)
  if [ -z "$date" ]; then
    date=$(basename "$file" .md | grep -oP '^\d{4}-\d{2}-\d{2}' || echo "")
  fi

  # sqlite3 param binding のために一時ファイルを使う
  local tmp
  tmp=$(mktemp)
  printf '%s' "$content" > "$tmp"

  sqlite3 "$DB" <<SQL
INSERT INTO memory_fts(path, layer, domain, date, importance, freshness, content)
VALUES (
  $(printf '%s' "$file" | sed "s|${REPO_ROOT}/||" | awk '{printf "\"%s\"", $0}'),
  "$layer",
  "$domain",
  "${date:-}",
  "${importance:-1.0}",
  "${freshness:-}",
  readfile('$tmp')
);
SQL
  rm -f "$tmp"
  count=$((count + 1))
  [ "$VERBOSE" = "--verbose" ] && echo "[fts-build] indexed: $file"
}

# daily/
for f in "${MEMORY_DIR}"/daily/*.md; do
  [ -f "$f" ] || continue
  insert_entry "$f" "daily" ""
done

# summaries/
for f in "${MEMORY_DIR}"/summaries/*.md; do
  [ -f "$f" ] || continue
  insert_entry "$f" "summaries" ""
done

# domains/{dev,product,biz}/**
for dom in dev product biz; do
  for f in "${MEMORY_DIR}"/domains/"$dom"/*.md; do
    [ -f "$f" ] || continue
    insert_entry "$f" "domains" "$dom"
  done
done

echo "[fts-build] Indexed ${count} file(s) into ${DB}"
