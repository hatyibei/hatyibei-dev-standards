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
あなたは hatyibei-dev-standards の Skill 設計者です。
既存の Skill スタイルに合わせて、新しい Skill の SKILL.md をマークダウンで作成してください。

## 要件
- YAML frontmatter (name, description, status: proposed, created) 付き
- セクション: ## 目的 / ## トリガー / ## 手順 / ## アンチパターン / ## 参考
- 日本語で記述、手順は番号付き
- **過剰設計禁止**: 既存 core/skills で代替できるなら言及して自重
- status は必ず "proposed" とする (未検証のため)

## 既存 Skill スタイル (few-shot)
\`\`\`markdown
${fewshot}
\`\`\`

## この Skill のスラッグ
${SLUG}

## 理由 / 提案元
${RATIONALE:-（ユーザー指定なし）}

## マイニング時のメタデータ
${candidate_json:-（該当なし）}

## 出力
SKILL.md の内容のみ。前置きや説明は不要。
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
