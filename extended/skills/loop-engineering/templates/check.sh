#!/bin/bash
# もふとーく fitness function — これが green 以外で「done」と言わない (CLAUDE.md ルール3)
set -e
cd "$(dirname "$0")"

echo "== syntax =="
for f in src/*.js tests/*.js; do
  [ -e "$f" ] || continue
  node --check "$f"
done

echo "== tests =="
if ls tests/*.test.js > /dev/null 2>&1; then
  node --test tests/*.test.js
else
  echo "(no tests yet)"
  exit 1
fi
echo "== CHECK GREEN =="
