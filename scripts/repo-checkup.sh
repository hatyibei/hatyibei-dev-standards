#!/usr/bin/env bash
# repo-checkup.sh — 自分の公開リポジトリの GitHub Actions / シークレット周りを毎月点検する
#
# 使い方: ./repo-checkup.sh OWNER [OUTDIR]     (OUTDIR 省略時は ./checkup-YYYYMMDD)
#
# 前提（このスクリプトはダウンロードもインストールもしない）:
#   必須: gh（gh auth login 済み）, git, jq, uv（uvx zizmor を使う）
#   任意: actionlint, gitleaks（PATH にあれば使う）, gh 拡張 actions-lock（入っていれば使う）
#   GH_TOKEN が未設定なら gh auth token から設定する（値は表示しない）。
#
# 読み取りのみ。GitHub 側の設定やリポジトリには一切書き込まない。
# 書くのは OUTDIR 以下（shallow clone とログ）だけ。見るのは各リポジトリの HEAD のみで、履歴は見ない。
set -uo pipefail

usage() { echo "usage: $0 OWNER [OUTDIR]" >&2; exit 2; }
[ $# -ge 1 ] && [ -n "$1" ] || usage
OWNER=$1
OUT=${2:-./checkup-$(date +%Y%m%d)}
LOG=$OUT/logs; WORK=$OUT/work

# ===== 0. 前提チェック =====
for c in gh git jq uv; do
  command -v "$c" >/dev/null 2>&1 || { echo "error: $c が見つかりません" >&2; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "error: gh にログインしていません（gh auth login）" >&2; exit 1; }
if [ -z "${GH_TOKEN:-}" ]; then
  GH_TOKEN="$(gh auth token 2>/dev/null)" || { echo "error: gh auth token に失敗" >&2; exit 1; }
  export GH_TOKEN                                     # 値は表示しない
fi
HAVE_ACTIONLINT=0; command -v actionlint >/dev/null 2>&1 && HAVE_ACTIONLINT=1
HAVE_GITLEAKS=0;   command -v gitleaks   >/dev/null 2>&1 && HAVE_GITLEAKS=1
HAVE_LOCK=0;       gh extension list 2>/dev/null | grep -q 'actions-lock' && HAVE_LOCK=1

mkdir -p "$LOG" "$WORK" || exit 1
date -Iseconds > "$LOG/00_started_at.txt"
{ gh --version | head -1; git --version; uv --version; jq --version; uvx zizmor --version
  [ $HAVE_ACTIONLINT = 1 ] && actionlint -version | head -1 || echo "actionlint: skipped (not in PATH)"
  [ $HAVE_GITLEAKS = 1 ] && echo "gitleaks $(gitleaks version)" || echo "gitleaks: skipped (not in PATH)"
  [ $HAVE_LOCK = 1 ] && echo "gh actions-lock: installed" || echo "gh actions-lock: skipped (not installed)"
} > "$LOG/00_versions.txt" 2>&1
echo "== tools =="; cat "$LOG/00_versions.txt"

# ===== 1. 公開リポジトリ一覧 =====
gh repo list "$OWNER" --visibility public --limit 1000 \
  --json name,isFork,isArchived,pushedAt > "$LOG/01_repos.json" \
  || { echo "error: $OWNER のリポジトリ一覧を取得できません" >&2; exit 1; }
REPOS=$(jq -r '.[].name' "$LOG/01_repos.json")
echo "repos: $(jq length "$LOG/01_repos.json")"

# ===== 2. shallow clone（HEAD のみ） =====
: > "$LOG/02_clone_failed.txt"
for r in $REPOS; do
  [ -d "$WORK/$r" ] || git clone --depth 1 --quiet "https://github.com/$OWNER/$r.git" "$WORK/$r" \
    || echo "$r" >> "$LOG/02_clone_failed.txt"
done
has_wf() { compgen -G "$1/.github/workflows/*.y*ml" >/dev/null || [ -f "$1/action.yml" ] || [ -f "$1/action.yaml" ]; }

# ===== 3. zizmor（0=指摘なし, 11〜14=指摘あり, それ以外=失敗） =====
echo "== zizmor =="
: > "$LOG/03_zizmor_exit.txt"; : > "$LOG/03_zizmor_failed.txt"
for r in $REPOS; do d=$WORK/$r; [ -d "$d" ] && has_wf "$d" || continue
  uvx zizmor --format=json "$d" > "$LOG/03_zizmor_$r.json" 2> "$LOG/03_zizmor_$r.stderr"; ec=$?
  echo "$r exit=$ec" >> "$LOG/03_zizmor_exit.txt"
  case $ec in 0|11|12|13|14) ;; *) echo "$r exit=$ec" >> "$LOG/03_zizmor_failed.txt" ;; esac
done
for f in "$LOG"/03_zizmor_*.json; do [ -s "$f" ] || continue
  r=${f##*/03_zizmor_}; r=${r%.json}
  jq -r --arg r "$r" '.[] | [$r, .ident, .determinations.severity] | @tsv' "$f" 2>/dev/null
done > "$LOG/03_zizmor_findings.tsv"
cut -f1 "$LOG/03_zizmor_findings.tsv" | sort | uniq -c | sort -rn > "$LOG/03_zizmor_by_repo.txt"
cut -f2,3 "$LOG/03_zizmor_findings.tsv" | sort | uniq -c | sort -rn > "$LOG/03_zizmor_by_rule.txt"

# ===== 4. actionlint =====
: > "$LOG/04_actionlint_exit.txt"
if [ $HAVE_ACTIONLINT = 1 ]; then echo "== actionlint =="
  for r in $REPOS; do d=$WORK/$r; [ -d "$d/.github/workflows" ] || continue
    ( cd "$d" && actionlint -oneline ) > "$LOG/04_actionlint_$r.txt" 2>&1
    echo "$r exit=$?" >> "$LOG/04_actionlint_exit.txt"   # 0=なし, 1=指摘あり, それ以外=失敗
  done
else echo "actionlint: skipped (not in PATH)"; fi

# ===== 5. gitleaks（HEAD のみ、--redact で値を伏せる） =====
: > "$LOG/05_gitleaks_summary.tsv"; echo 0 > "$LOG/05_unredacted_count.txt"
if [ $HAVE_GITLEAKS = 1 ]; then echo "== gitleaks =="
  for r in $REPOS; do d=$WORK/$r; [ -d "$d" ] || continue
    gitleaks dir "$d" --redact --no-banner --exit-code 0 -f json -r "$LOG/05_gitleaks_$r.json" \
      2>> "$LOG/05_gitleaks_stderr.txt"
  done
  cat "$LOG"/05_gitleaks_*.json 2>/dev/null | jq -s '[.[][] | select(.Secret != "REDACTED")] | length' \
    > "$LOG/05_unredacted_count.txt"                     # 0 以外なら該当 JSON をすぐ削除すること
  for f in "$LOG"/05_gitleaks_*.json; do [ -s "$f" ] || continue
    r=${f##*/05_gitleaks_}; r=${r%.json}
    jq -r --arg r "$r" '.[] | [$r, .RuleID, .File, (.StartLine|tostring)] | @tsv' "$f"
  done > "$LOG/05_gitleaks_summary.tsv"                  # ルール名・ファイル・行だけ
else echo "gitleaks: skipped (not in PATH)"; fi

# ===== 6. gh actions-lock --no-fix（ファイルは書き換えない） =====
if [ $HAVE_LOCK = 1 ]; then echo "== gh actions-lock --no-fix =="
  for r in $REPOS; do d=$WORK/$r; [ -d "$d/.github/workflows" ] || continue
    ( cd "$d" && gh actions-lock --no-fix ) > "$LOG/06_actions_lock_$r.txt" 2>&1
  done
else echo "gh actions-lock: skipped (not installed)"; fi

# ===== 7. GITHUB_TOKEN の既定権限（読み取りのみ） =====
echo "== default GITHUB_TOKEN permissions =="
for r in $REPOS; do
  printf '%s\t' "$r"
  gh api "repos/$OWNER/$r/actions/permissions/workflow" \
    --jq '[.default_workflow_permissions, .can_approve_pull_request_reviews] | @tsv' 2>/dev/null \
    || echo "unavailable"
done > "$LOG/07_default_token_perms.tsv"

# ===== 8. summary =====
{
  echo "owner: $OWNER   date: $(date -Iseconds)"
  echo "public repos: $(jq length "$LOG/01_repos.json")   clone failed: $(wc -l < "$LOG/02_clone_failed.txt")"
  echo "--- zizmor: findings $(wc -l < "$LOG/03_zizmor_findings.tsv"), failed runs $(wc -l < "$LOG/03_zizmor_failed.txt") ---"
  echo "[by repo]";            cat "$LOG/03_zizmor_by_repo.txt"
  echo "[by rule / severity]"; cat "$LOG/03_zizmor_by_rule.txt"
  if [ $HAVE_ACTIONLINT = 1 ]; then
    echo "--- actionlint: repos with findings $(grep -cv 'exit=0$' "$LOG/04_actionlint_exit.txt") ---"
    grep -v 'exit=0$' "$LOG/04_actionlint_exit.txt"
  else echo "--- actionlint: skipped (not in PATH) ---"; fi
  if [ $HAVE_GITLEAKS = 1 ]; then
    echo "--- gitleaks (HEAD only): hits $(wc -l < "$LOG/05_gitleaks_summary.tsv"), unredacted $(cat "$LOG/05_unredacted_count.txt") ---"
    cut -f1,2 "$LOG/05_gitleaks_summary.tsv" | sort | uniq -c | sort -rn
  else echo "--- gitleaks: skipped (not in PATH) ---"; fi
  [ $HAVE_LOCK = 1 ] && echo "--- gh actions-lock: see logs/06_actions_lock_*.txt ---" \
    || echo "--- gh actions-lock: skipped (not installed) ---"
  echo "--- default GITHUB_TOKEN permissions (repo / default / can_approve_pr) ---"
  awk -F'\t' '{print $2}' "$LOG/07_default_token_perms.tsv" | sort | uniq -c
  grep -P '\twrite\t|\ttrue$' "$LOG/07_default_token_perms.tsv"
  echo "elapsed_sec: $SECONDS"
} > "$OUT/summary.txt"
echo; cat "$OUT/summary.txt"
