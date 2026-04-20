#!/bin/bash
# mine-patterns.sh — 直近 N 日の daily/*.md から頻出パターン（タスク/エラー/判断）を抽出
#
# 使い方:
#   bash tools/curation/mine-patterns.sh                 # 直近 14 日
#   bash tools/curation/mine-patterns.sh --days 30
#   bash tools/curation/mine-patterns.sh --summarize     # Haiku で要約 (要 ANTHROPIC_API_KEY)
#
# 出力: skills/_generated/.candidates/patterns-YYYY-MM-DD.json
#
# 依存: grep, sort, uniq, jq; optional: sqlite3, curl

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
MEMORY_DIR="${REPO_ROOT}/.harness/memory"
OUT_DIR="${REPO_ROOT}/skills/_generated/.candidates"
DAYS=14
SUMMARIZE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --summarize) SUMMARIZE=1; shift ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUT_DIR"
TODAY=$(date +%Y-%m-%d)
OUT="${OUT_DIR}/patterns-${TODAY}.json"

# 直近 N 日の daily ファイル
CUTOFF=$(date -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-"${DAYS}"d +%Y-%m-%d)

files=()
for f in "${MEMORY_DIR}"/daily/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  # YYYY-MM-DD 形式のみ対象
  [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
  [[ "$name" > "$CUTOFF" || "$name" = "$CUTOFF" ]] && files+=("$f")
done

if [ "${#files[@]}" -eq 0 ]; then
  echo "[mine-patterns] No daily files in the last ${DAYS} days. Nothing to mine."
  echo '{"window_days":'"$DAYS"',"files_scanned":0,"patterns":[]}' > "$OUT"
  echo "[mine-patterns] Empty result written to: $OUT"
  exit 0
fi

echo "[mine-patterns] Scanning ${#files[@]} file(s) from last ${DAYS} days..."

# 頻出パターンのシグナル抽出
# 1) 意思決定キーワード周辺
decisions=$(grep -hEi "(decided|chose|rejected|決定|判断)" "${files[@]}" 2>/dev/null | sort | uniq -c | sort -rn | head -20 || true)
# 2) エラー・修正
errors=$(grep -hEi "(error|bug|fix|failed|障害|修正)" "${files[@]}" 2>/dev/null | sort | uniq -c | sort -rn | head -20 || true)
# 3) ツール・コマンド呼び出し
tools_used=$(grep -hoE '`[a-z][a-z0-9_-]+`' "${files[@]}" 2>/dev/null | sort | uniq -c | sort -rn | head -20 || true)
# 4) 見出し (## ...)
headings=$(grep -hE '^## ' "${files[@]}" 2>/dev/null | sort | uniq -c | sort -rn | head -20 || true)

# JSON 化 (jq で安全に)
jq -n \
  --arg window "$DAYS" \
  --arg generated_at "$TODAY" \
  --arg scanned "${#files[@]}" \
  --arg decisions "$decisions" \
  --arg errors "$errors" \
  --arg tools "$tools_used" \
  --arg headings "$headings" \
  '{
    window_days: ($window | tonumber),
    generated_at: $generated_at,
    files_scanned: ($scanned | tonumber),
    signals: {
      decisions: $decisions,
      errors: $errors,
      tools: $tools,
      headings: $headings
    }
  }' > "$OUT"

echo "[mine-patterns] Pattern signals written to: $OUT"

# オプション: Haiku で要約してパターン候補を作る
if [ "$SUMMARIZE" -eq 1 ]; then
  if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[mine-patterns] --summarize requires ANTHROPIC_API_KEY. Skipping." >&2
    exit 0
  fi
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/tools/lib/claude-api.sh"

  prompt=$(cat <<EOF
Below are recurring signals mined from the last ${DAYS} days of dev logs.
Suggest up to 5 candidates that are **worth extracting as new Skills**.

## Output format (JSON only, no explanation)
{
  "candidates": [
    {
      "slug": "kebab-case-skill-name",
      "title": "Human-readable title (Japanese is fine)",
      "rationale": "Why this deserves a Skill (1-2 sentences)",
      "trigger": "When this Skill should be invoked",
      "frequency_hint": "How often it appeared in the signals"
    }
  ]
}

## Signals
$(cat "$OUT")
EOF
)
  echo "[mine-patterns] Asking Haiku for candidate skills..."
  response=$(call_claude "$HAIKU_MODEL" "$prompt" 2048)
  text=$(extract_text "$response")
  json=$(echo "$text" | awk '/^```json/{flag=1;next}/^```/{flag=0}flag' | head -100)
  [ -z "$json" ] && json="$text"

  candidates_file="${OUT_DIR}/candidates-${TODAY}.json"
  echo "$json" > "$candidates_file"
  echo "[mine-patterns] Candidate skills written to: $candidates_file"
  echo ""
  echo "Next: bash tools/curation/propose-skill.sh <slug>"
fi
