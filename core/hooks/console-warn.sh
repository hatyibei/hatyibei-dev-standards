#!/bin/bash
# PostToolUse hook: Warn about console.log in edited code
# Catches debug logging left in production code

input=$(cat)
new_string=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('new_string',''))" 2>/dev/null)
file_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Only check JS/TS files
case "$file_path" in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac

if echo "$new_string" | grep -qE 'console\.(log|debug|info)\('; then
  echo "NOTE: console.log/debug/info が含まれています。デバッグ用なら本番前に削除してください。" >&2
fi

exit 0
