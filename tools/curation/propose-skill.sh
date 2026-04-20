#!/bin/bash
# propose-skill.sh — Opus に SKILL.md ドラフトを生成させる
#
# 使い方:
#   bash tools/curation/propose-skill.sh <slug> [rationale]
#   bash tools/curation/propose-skill.sh stripe-refund "Stripe 返金フローの定型化"
#
# 入力: 最新 candidates-YYYY-MM-DD.json に <slug> があれば文脈利用
# 出力: skills/_generated/YYYY-MM-DD-<slug>/SKILL.md
#
# 依存: jq, curl, ANTHROPIC_API_KEY

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
GEN_DIR="${REPO_ROOT}/skills/_generated"
CANDIDATES_DIR="${GEN_DIR}/.candidates"

SLUG="${1:-}"
RATIONALE="${2:-}"

if [ -z "$SLUG" ]; then
  echo "Usage: $0 <slug> [rationale]" >&2
  exit 1
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "[propose-skill] ERROR: ANTHROPIC_API_KEY is not set." >&2
  exit 1
fi

# shellcheck source=/dev/null
CLAUDE_API_MAX_TOKENS=4096 source "${REPO_ROOT}/tools/lib/claude-api.sh"

TODAY=$(date +%Y-%m-%d)
OUT_DIR="${GEN_DIR}/${TODAY}-${SLUG}"
mkdir -p "$OUT_DIR"

# candidates から該当 slug の情報を拾う
latest_candidates=$(ls -t "${CANDIDATES_DIR}"/candidates-*.json 2>/dev/null | head -1 || echo "")
candidate_json=""
if [ -n "$latest_candidates" ] && [ -f "$latest_candidates" ]; then
  candidate_json=$(jq -r --arg s "$SLUG" '.candidates[]? | select(.slug == $s) // empty' "$latest_candidates" 2>/dev/null || echo "")
fi

# few-shot として core/skills/deploy/SKILL.md 冒頭を添付
fewshot=""
if [ -f "${REPO_ROOT}/core/skills/deploy/SKILL.md" ]; then
  fewshot=$(head -60 "${REPO_ROOT}/core/skills/deploy/SKILL.md")
fi

prompt=$(cat <<EOF
You are a Skill designer for hatyibei-dev-standards.
Draft a new Skill as a SKILL.md in the existing house style.

## Requirements
- YAML frontmatter (name, description, status: proposed, created)
- Sections: ## Purpose / ## Triggers / ## Procedure / ## Anti-patterns / ## References
- Numbered procedure
- **No over-engineering**: if an existing core/skills entry already covers this, say so and stop
- status MUST be "proposed" (unverified)
- Body language: English preferred for token efficiency; Japanese is acceptable for user-facing phrasing

## Existing Skill style (few-shot)
\`\`\`markdown
${fewshot}
\`\`\`

## Slug
${SLUG}

## Rationale / source
${RATIONALE:-(not supplied)}

## Mining metadata
${candidate_json:-(none)}

## Output
The SKILL.md content only. No preamble, no explanation.
EOF
)

echo "[propose-skill] Asking Opus to draft SKILL.md for: $SLUG"
response=$(call_claude "$OPUS_MODEL" "$prompt" 4096)
text=$(extract_text "$response")

if [ -z "$text" ]; then
  echo "[propose-skill] ERROR: empty response from Opus." >&2
  echo "$response" | jq . >&2 || echo "$response" >&2
  exit 1
fi

# コードブロックで囲まれていたら剥がす
skill_md=$(echo "$text" | awk '
  /^```markdown/ { in_block=1; next }
  /^```md/ { in_block=1; next }
  /^```$/ && in_block { in_block=0; next }
  in_block { print; next }
  !seen_block { print }
' | sed '/^$/N;/^\n$/D')

# フォールバック: コードブロックが無かった場合は raw を使う
[ -z "$skill_md" ] && skill_md="$text"

out_file="${OUT_DIR}/SKILL.md"
printf '%s\n' "$skill_md" > "$out_file"

# メタ情報も一緒に保存
cat > "${OUT_DIR}/META.yml" <<EOF
slug: ${SLUG}
status: proposed
generated_at: ${TODAY}
generator: propose-skill.sh (Opus)
source_candidates: ${latest_candidates:-none}
promoted: false
promotion_target: null
EOF

echo "[propose-skill] Draft written to: $out_file"
echo "[propose-skill] Meta: ${OUT_DIR}/META.yml"
echo ""
echo "Next: review the draft, then run:"
echo "  bash tools/curation/promote.sh ${TODAY}-${SLUG}"
