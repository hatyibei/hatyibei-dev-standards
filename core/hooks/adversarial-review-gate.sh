#!/bin/bash
# Stop hook: 実装をユーザーに差し出す前に敵対的レビューを通させる
#
# 「動いた」と「壊れていない」は別。ゲート (lint/typecheck/test) は自分が書いた前提の
# 正しさしか見ないため、前提そのものが間違っている欠陥は素通りする。承認を仰ぐ直前は
# その欠陥が最も残りやすいので、ここで一度止めて別視点のレビューを挟ませる。
#
# exit 2 で Stop をブロックし、stderr がモデルに返る (実行するのはモデル側)。
# 「レビュー済み」の記録は tools/review/mark-adversarial-review.sh が残す。

set -u

# --- 無効化 (緊急時・CI) -------------------------------------------------
[ "${ADVERSARIAL_REVIEW_GATE:-on}" = "off" ] && exit 0
[ -n "${CI:-}" ] && exit 0

input=$(cat)

# stop_hook_active が true = 既にこのフックで一度止めた後。無限ループを避ける
active=$(printf '%s' "$input" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null)
[ "$active" = "True" ] && exit 0

cwd=$(printf '%s' "$input" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# --- 対象の変更量を測る ---------------------------------------------------
# 「まだ共有されていない変更」= 未コミット + 未 push。ここが承認の対象になる
base=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "origin/main")
git rev-parse --verify -q "$base" >/dev/null 2>&1 || base="origin/main"
git rev-parse --verify -q "$base" >/dev/null 2>&1 || exit 0

# 未追跡ファイル (新規追加) も数える。git diff では拾えない
changed=$( { git diff --name-only "$base" 2>/dev/null; git diff --name-only --cached; git diff --name-only; \
             git ls-files --others --exclude-standard; } \
  | sort -u | grep -vcE '^[[:space:]]*$' )
[ "${changed:-0}" -lt "${ADVERSARIAL_REVIEW_MIN_FILES:-5}" ] && exit 0

# --- レビュー済みか (対象の内容が変わっていないか) -------------------------
state=$(git rev-parse --git-dir)/adversarial-review.state
# 未追跡ファイルの中身も含める (新規ファイルだけの変更で記録が効いてしまうのを防ぐ)
current=$( { git rev-parse HEAD; git diff "$base"; git diff; git diff --cached; \
             git ls-files --others --exclude-standard -z | xargs -0 shasum 2>/dev/null; } \
  2>/dev/null | shasum | cut -d' ' -f1)
[ -f "$state" ] && [ "$(cat "$state" 2>/dev/null)" = "$current" ] && exit 0

cat >&2 <<EOF
BLOCKED: 敵対的レビュー未実施のままユーザーに承認を求めようとしています (変更 ${changed} ファイル)。

ゲート (lint/typecheck/test) は「自分が書いた前提」の中でしか検証できません。
前提そのものが誤っている欠陥は素通りするため、差し出す前に別視点を通してください。

  1. 観点を分けて並行にレビューさせる (例: 認可 / データ整合性 / 実行系 / リリース安全性)
     - subagent (Agent tool) と codex-cli-review skill を併用すると視点が分散する
     - 「問題ありません」を求めないこと。壊しにいく指示を出す
  2. 指摘は実コードで裏を取ってから採否を決める (推測のまま直さない・切り捨てない)
  3. 通ったら記録する:
       bash tools/review/mark-adversarial-review.sh

一時的に外す場合: ADVERSARIAL_REVIEW_GATE=off
EOF
exit 2
