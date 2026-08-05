#!/bin/bash
# 敵対的レビューを通したことを記録する (core/hooks/adversarial-review-gate.sh を解除する)
#
# 記録は「今の変更内容のハッシュ」なので、この後コードを変えると自動で無効になる。
# レビューせずに素通りさせないための仕掛けであり、書き換えた後は再度レビューが要る。

set -eu

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "git リポジトリ内で実行してください" >&2
  exit 1
}

base=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "origin/main")
git rev-parse --verify -q "$base" >/dev/null 2>&1 || base="origin/main"

state=$(git rev-parse --git-dir)/adversarial-review.state
{ git rev-parse HEAD; git diff "$base"; git diff; git diff --cached; \
  git ls-files --others --exclude-standard -z | xargs -0 shasum 2>/dev/null; } 2>/dev/null \
  | shasum | cut -d' ' -f1 > "$state"

echo "記録しました: $state"
echo "(この後コードを変更すると記録は無効になり、再度レビューが必要になります)"
