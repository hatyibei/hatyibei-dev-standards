#!/bin/bash
# recall.sh — .harness/memory/** 横断の統一検索 CLI
#
# 使い方:
#   bash tools/search/recall.sh "pgvector"           # 全層を検索
#   bash tools/search/recall.sh --layer daily "ADR-010"
#   bash tools/search/recall.sh --domain dev "cache"
#   bash tools/search/recall.sh --limit 20 "xss"
#
# 動作:
#   1. sqlite3 + FTS5 インデックスがあればそれを使用 (importance 降順)
#   2. 無ければ grep -rn にフォールバック
#
# 依存: sqlite3 (optional), grep

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
MEMORY_DIR="${REPO_ROOT}/.harness/memory"
DB="${MEMORY_DIR}/.index/memory.db"

LAYER=""
DOMAIN=""
LIMIT=10
QUERY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --layer) LAYER="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) QUERY="$*"; break ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "Usage: $0 [--layer daily|summaries|domains] [--domain dev|product|biz] [--limit N] <query>" >&2
  exit 1
fi

# FTS5 パス
if command -v sqlite3 >/dev/null 2>&1 && [ -f "$DB" ]; then
  WHERE="memory_fts MATCH ?"
  FILTERS=""
  [ -n "$LAYER" ] && FILTERS="${FILTERS} AND layer = '$LAYER'"
  [ -n "$DOMAIN" ] && FILTERS="${FILTERS} AND domain = '$DOMAIN'"

  # FTS5 MATCH は ? でバインド不可なので escape して直接入れる
  SAFE_QUERY=$(printf '%s' "$QUERY" | sed "s/'/''/g")

  echo "# FTS5 results for: $QUERY"
  sqlite3 -separator ' | ' "$DB" <<SQL
SELECT
  printf('%.1f', CAST(importance AS REAL)) AS imp,
  layer,
  COALESCE(NULLIF(domain,''),'-') AS dom,
  COALESCE(NULLIF(date,''),'-') AS dt,
  path,
  snippet(memory_fts, 6, '<<', '>>', '...', 20) AS snip
FROM memory_fts
WHERE memory_fts MATCH '$SAFE_QUERY'
${FILTERS}
ORDER BY CAST(importance AS REAL) DESC, date DESC
LIMIT ${LIMIT};
SQL
  exit 0
fi

# grep フォールバック
echo "# grep fallback (sqlite3 or index unavailable)"
SEARCH_ROOTS=()
if [ -n "$LAYER" ]; then
  case "$LAYER" in
    daily|summaries|domains) SEARCH_ROOTS+=("${MEMORY_DIR}/${LAYER}") ;;
    *) echo "unknown layer: $LAYER" >&2; exit 1 ;;
  esac
else
  SEARCH_ROOTS+=("${MEMORY_DIR}/daily" "${MEMORY_DIR}/summaries" "${MEMORY_DIR}/domains")
fi

if [ -n "$DOMAIN" ] && [ -z "$LAYER" ]; then
  SEARCH_ROOTS=("${MEMORY_DIR}/domains/${DOMAIN}")
elif [ -n "$DOMAIN" ] && [ "$LAYER" = "domains" ]; then
  SEARCH_ROOTS=("${MEMORY_DIR}/domains/${DOMAIN}")
fi

for root in "${SEARCH_ROOTS[@]}"; do
  [ -d "$root" ] || continue
  grep -rn --include='*.md' -i -- "$QUERY" "$root" 2>/dev/null | head -n "$LIMIT" || true
done
