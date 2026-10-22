#!/usr/bin/env bash
# Comprueba que las páginas de la wiki y el índice son coherentes.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIKI="$REPO_DIR/wiki"
FAIL=0

[[ -f "$WIKI/Home.md" ]] || { echo "[FAIL] falta wiki/Home.md" >&2; FAIL=1; }
[[ -f "$WIKI/_Sidebar.md" ]] || { echo "[FAIL] falta wiki/_Sidebar.md" >&2; FAIL=1; }

while IFS= read -r page; do
  [[ -n "$page" ]] || continue
  if [[ ! -f "$WIKI/$page.md" ]]; then
    echo "[FAIL] _Sidebar enlaza a '$page' pero no existe wiki/$page.md" >&2
    FAIL=1
  fi
done < <(sed -nE 's/.*\]\(([^)]+)\).*/\1/p' "$WIKI/_Sidebar.md" | sort -u)

for file in "$WIKI"/*.md; do
  base="$(basename "$file")"
  if [[ "$base" == _* ]]; then
    continue
  fi
  if ! grep -q '^# ' "$file"; then
    echo "[FAIL] $base no tiene un título de nivel 1" >&2
    FAIL=1
  fi
  if grep -q '@@' "$file"; then
    echo "[FAIL] $base contiene placeholders sin sustituir" >&2
    FAIL=1
  fi
done

if [[ "$FAIL" == "0" ]]; then
  echo "wiki-test: OK"
  exit 0
fi
exit 1
