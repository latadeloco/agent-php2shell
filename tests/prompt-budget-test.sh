#!/usr/bin/env bash
# Comprueba que el prompt mantiene el presupuesto y las reglas clave.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT="$REPO_DIR/core/prompt.md"
FAIL=0

words="$(wc -w < "$PROMPT" | tr -d ' ')"
if [[ "$words" -le 1600 ]]; then
  echo "[ok] prompt dentro del presupuesto: $words palabras"
else
  echo "[FAIL] prompt demasiado largo: $words palabras (máximo 1600)" >&2
  FAIL=1
fi

for phrase in \
  "Presupuesto de respuesta" \
  "10–12 líneas" \
  "CONFIRMO QUE TENGO PERMISO" \
  "--i-have-permission" \
  "preflight.sh --brief" \
  "php2shell-triage.sh --summary" \
  "php2shell-bt.sh" \
  "CONFIRMO LA PRUEBA AVANZADA" \
  "NO SIGNAL" \
  "Assetnote" \
  "Sairahcaz" \
  "Calif"; do
  if ! grep -qF -- "$phrase" "$PROMPT"; then
    echo "[FAIL] falta la frase clave: $phrase" >&2
    FAIL=1
  fi
done

if grep -qE 'php2shell-scan\.sh.*-v' "$PROMPT"; then
  echo "[FAIL] el comando de escaneo vuelve a usar -v" >&2
  FAIL=1
else
  echo "[ok] el escaneo no usa -v por defecto"
fi

if [[ "$FAIL" == "0" ]]; then
  echo "prompt-budget-test: OK"
  exit 0
fi
exit 1
