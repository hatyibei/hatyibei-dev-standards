#!/bin/bash
# PreToolUse hook: Warn when modifying linter/formatter/build config files
# Prevents "weaken the config instead of fixing the code" pattern

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

protected_patterns=(
  '.eslintrc' '.eslintrc.js' '.eslintrc.json' '.eslintrc.yml' 'eslint.config'
  '.prettierrc' '.prettierrc.js' '.prettierrc.json' 'prettier.config'
  'biome.json' 'biome.jsonc'
  '.stylelintrc'
  'tsconfig.json' 'tsconfig.*.json'
  '.editorconfig'
)

basename=$(basename "$file_path" 2>/dev/null)

for pattern in "${protected_patterns[@]}"; do
  if [[ "$basename" == $pattern ]]; then
    echo "WARNING: 設定ファイル ($basename) を変更しようとしています。コードを修正する代わりに設定を弱めていませんか？本当に必要な場合のみ変更してください。" >&2
    exit 0  # warn only, don't block
  fi
done

exit 0
