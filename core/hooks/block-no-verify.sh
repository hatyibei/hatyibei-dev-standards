#!/bin/bash
# PreToolUse hook: Block --no-verify and --no-gpg-sign flags
# Prevents bypassing git hooks and commit signing

input=$(cat)
command=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

if echo "$command" | grep -qE '\-\-no-verify|\-\-no-gpg-sign'; then
  echo "BLOCKED: --no-verify / --no-gpg-sign の使用は禁止されています。git hookをバイパスせずに問題を修正してください。" >&2
  exit 2
fi

exit 0
