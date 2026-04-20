#!/bin/bash
# promote.sh — skills/_generated/<slug>/SKILL.md を extended/ または core/ に昇格させるためのチェックリスト表示
#
# 使い方:
#   bash tools/curation/promote.sh 2026-04-20-stripe-refund
#   bash tools/curation/promote.sh 2026-04-20-stripe-refund --target extended
#   bash tools/curation/promote.sh 2026-04-20-stripe-refund --target core
#   bash tools/curation/promote.sh --audit         # 30日超の未昇格を警告
#
# このスクリプトは **自動コピーしない**。人間レビューを必須とする。
# 出力される手順に従って手動で git mv / 調整すること。

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
GEN_DIR="${REPO_ROOT}/skills/_generated"

SLUG=""
TARGET="extended"
AUDIT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --audit) AUDIT=1; shift ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) SLUG="$1"; shift ;;
  esac
done

if [ "$AUDIT" -eq 1 ]; then
  echo "# Audit: _generated/ entries older than 30 days"
  now_epoch=$(date +%s)
  found=0
  for d in "${GEN_DIR}"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    case "$name" in .*) continue ;; esac
    # YYYY-MM-DD-slug 形式前提
    date_part=$(echo "$name" | grep -oP '^\d{4}-\d{2}-\d{2}' || echo "")
    [ -z "$date_part" ] && continue
    entry_epoch=$(date -d "$date_part" +%s 2>/dev/null || date -jf "%Y-%m-%d" "$date_part" +%s 2>/dev/null || continue)
    age_days=$(( (now_epoch - entry_epoch) / 86400 ))
    if [ "$age_days" -gt 30 ]; then
      echo "  - ${name} (${age_days} days old)"
      found=$((found + 1))
    fi
  done
  [ "$found" -eq 0 ] && echo "  (none — good hygiene)"
  echo ""
  echo "Recommendation: promote to extended/ or delete if obsolete."
  exit 0
fi

if [ -z "$SLUG" ]; then
  echo "Usage: $0 <YYYY-MM-DD-slug> [--target extended|core]" >&2
  echo "       $0 --audit" >&2
  exit 1
fi

SRC_DIR="${GEN_DIR}/${SLUG}"
SRC_SKILL="${SRC_DIR}/SKILL.md"

if [ ! -f "$SRC_SKILL" ]; then
  echo "[promote] ERROR: ${SRC_SKILL} not found." >&2
  exit 1
fi

case "$TARGET" in
  extended) DEST_DIR="${REPO_ROOT}/extended/skills/$(echo "$SLUG" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')" ;;
  core)     DEST_DIR="${REPO_ROOT}/core/skills/$(echo "$SLUG" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')" ;;
  *) echo "[promote] ERROR: --target must be 'extended' or 'core'" >&2; exit 1 ;;
esac

cat <<EOF
# Promotion checklist for: ${SLUG} → ${TARGET}/

Review the draft first:
  cat ${SRC_SKILL}

## Pre-promotion checks

- [ ] SKILL.md の YAML frontmatter が揃っている (name, description, status, created)
- [ ] 既存 core/skills と重複していない (特に: $(ls ${REPO_ROOT}/core/skills 2>/dev/null | tr '\n' ' '))
- [ ] アンチパターン節で「過剰設計警告」が適切
- [ ] 例示コマンドが実際に動く
- [ ] 日本語/英語の表記揺れがない

## Promotion rules (from ADR-009)

EOF

case "$TARGET" in
  extended)
    cat <<EOF
**extended/ 昇格基準**:
- _generated/ で最低 1 セッション人間レビュー通過
- 既存 extended/ と責務が重ならない

手動コマンド:
  mkdir -p "${DEST_DIR}"
  cp "${SRC_SKILL}" "${DEST_DIR}/SKILL.md"
  # status: proposed → status: extended に書き換え
  sed -i 's/^status: proposed$/status: extended/' "${DEST_DIR}/SKILL.md"
  # META を更新
  sed -i "s/^promoted: false/promoted: true/" "${SRC_DIR}/META.yml"
  sed -i "s|^promotion_target: null|promotion_target: extended/skills/|" "${SRC_DIR}/META.yml"
  git add "${DEST_DIR}" "${SRC_DIR}/META.yml"
EOF
    ;;
  core)
    cat <<EOF
**core/ 昇格基準 (厳格)**:
- extended/ で月 1 回以上の発火実績が 3 ヶ月継続
- actually_used.md に反映済み
- 失敗コスト高 (課金/セキュリティ/本番) または使用頻度高

手動コマンド:
  mkdir -p "${DEST_DIR}"
  cp "${SRC_SKILL}" "${DEST_DIR}/SKILL.md"
  sed -i 's/^status: .*/status: core/' "${DEST_DIR}/SKILL.md"
  sed -i "s/^promoted: false/promoted: true/" "${SRC_DIR}/META.yml"
  sed -i "s|^promotion_target: null|promotion_target: core/skills/|" "${SRC_DIR}/META.yml"
  # actually_used.md の更新も忘れずに
  git add "${DEST_DIR}" "${SRC_DIR}/META.yml" actually_used.md
EOF
    ;;
esac

cat <<EOF

## Post-promotion

- [ ] 動作確認 (Claude Code セッションで /<skill-name> 呼び出し)
- [ ] 2 週間後の actually_used レビューで発火実績をチェック
- [ ] 未発火なら extended/ に降格または _generated/ に戻す

## 参考 ADR
- ADR-009: Core 選定基準
- ADR-012: hermes-agent 参考の再編
EOF
