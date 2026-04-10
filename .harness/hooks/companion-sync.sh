#!/bin/bash
# companion-sync.sh — Vane (companion) のソウルデータをリポジトリと同期
#
# SessionStart: リポジトリ → ~/.claude.json に復元
# SessionEnd:   ~/.claude.json → リポジトリにバックアップ
#
# 使い方:
#   bash .harness/hooks/companion-sync.sh pull   # リポジトリ → ローカル
#   bash .harness/hooks/companion-sync.sh push   # ローカル → リポジトリ
#   bash .harness/hooks/companion-sync.sh auto   # 差分があれば新しい方を採用

set -euo pipefail

HARNESS_ROOT="${HARNESS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)/.harness}"
REPO_FILE="${HARNESS_ROOT}/companion/companion.json"
LOCAL_FILE="${HOME}/.claude.json"
MODE="${1:-auto}"

# --- ヘルパー ---

# ~/.claude.json から companion を抽出
get_local_companion() {
  python3 -c "
import json, sys
try:
    with open('${LOCAL_FILE}') as f:
        d = json.load(f)
    print(json.dumps(d.get('companion', {}), ensure_ascii=False))
except:
    print('{}')
" 2>/dev/null
}

# ~/.claude.json に companion を書き込み（他のキーは保持）
set_local_companion() {
  local companion_json="$1"
  python3 -c "
import json, sys
companion = json.loads('''${companion_json}''')
try:
    with open('${LOCAL_FILE}') as f:
        d = json.load(f)
except:
    d = {}
d['companion'] = companion
with open('${LOCAL_FILE}', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
" 2>/dev/null
}

# --- メイン ---

do_pull() {
  if [ ! -f "$REPO_FILE" ]; then
    echo "[companion-sync] No repo companion data. Skipping pull."
    return 0
  fi

  local repo_data
  repo_data=$(cat "$REPO_FILE")

  if [ "$repo_data" = "{}" ] || [ -z "$repo_data" ]; then
    echo "[companion-sync] Repo companion data is empty. Skipping."
    return 0
  fi

  set_local_companion "$repo_data"
  echo "[companion-sync] Pulled: repo → local"
}

do_push() {
  local local_data
  local_data=$(get_local_companion)

  if [ "$local_data" = "{}" ] || [ -z "$local_data" ]; then
    echo "[companion-sync] No local companion data. Skipping push."
    return 0
  fi

  mkdir -p "$(dirname "$REPO_FILE")"
  echo "$local_data" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2, ensure_ascii=False))" > "$REPO_FILE"
  echo "[companion-sync] Pushed: local → repo"
}

do_auto() {
  local local_data repo_data
  local_data=$(get_local_companion)
  repo_data=$(cat "$REPO_FILE" 2>/dev/null || echo "{}")

  # 両方空なら何もしない
  if [ "$local_data" = "{}" ] && [ "$repo_data" = "{}" ]; then
    echo "[companion-sync] No companion data anywhere. Skipping."
    return 0
  fi

  # ローカルが空→pull
  if [ "$local_data" = "{}" ]; then
    do_pull
    return 0
  fi

  # リポジトリが空→push
  if [ "$repo_data" = "{}" ]; then
    do_push
    return 0
  fi

  # 両方あるなら hatchedAt を比較（新しい方を採用）
  local local_hatched repo_hatched
  local_hatched=$(echo "$local_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('hatchedAt',0))" 2>/dev/null || echo 0)
  repo_hatched=$(echo "$repo_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('hatchedAt',0))" 2>/dev/null || echo 0)

  # 同じなら名前・性格の差分をチェック
  if [ "$local_hatched" = "$repo_hatched" ]; then
    local local_name repo_name
    local_name=$(echo "$local_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name',''))" 2>/dev/null)
    repo_name=$(echo "$repo_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name',''))" 2>/dev/null)

    if [ "$local_name" != "$repo_name" ]; then
      # ローカルが変更されたとみなしてpush
      do_push
    else
      echo "[companion-sync] Already in sync."
    fi
    return 0
  fi

  # hatchedAt が新しい方を採用
  if [ "$local_hatched" -gt "$repo_hatched" ] 2>/dev/null; then
    do_push
  else
    do_pull
  fi
}

case "$MODE" in
  pull)  do_pull ;;
  push)  do_push ;;
  auto)  do_auto ;;
  *)
    echo "Usage: $0 {pull|push|auto}"
    exit 1
    ;;
esac
