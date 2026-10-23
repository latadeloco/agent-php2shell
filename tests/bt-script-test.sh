#!/usr/bin/env bash
# Comprobaciones estáticas de la copia vendorizada de php2shellbt.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_DIR/vendor/php2shellbt/php2shellbt.py"
FAIL=0

[[ -f "$SCRIPT" ]] || { echo "[FAIL] falta $SCRIPT" >&2; exit 1; }

if grep -q 'ssl.create_default_context' "$SCRIPT"; then
  echo "[ok] contexto TLS presente"
else
  echo "[FAIL] no se crea un contexto TLS" >&2
  FAIL=1
fi

if grep -q -- '--insecure' "$SCRIPT" && grep -q 'CERT_NONE' "$SCRIPT"; then
  echo "[ok] --insecure controlado"
else
  echo "[FAIL] falta el control --insecure" >&2
  FAIL=1
fi

if grep -q -- '--targets' "$SCRIPT"; then
  echo "[FAIL] el script todavía acepta --targets" >&2
  FAIL=1
else
  echo "[ok] sin listas de objetivos"
fi

if grep -q 'PHP payload in session file was executed' "$SCRIPT"; then
  echo "[FAIL] el payload sigue imprimiéndose" >&2
  FAIL=1
else
  echo "[ok] payload no impreso"
fi

if grep -q -- '--checks' "$SCRIPT"; then
  echo "[ok] selector --checks presente"
else
  echo "[FAIL] falta --checks" >&2
  FAIL=1
fi

if command -v python3 >/dev/null 2>&1; then
  if python3 -m py_compile "$SCRIPT" 2>/dev/null; then
    echo "[ok] sintaxis Python"
    rm -rf "$REPO_DIR/vendor/php2shellbt/__pycache__"
  else
    echo "[FAIL] error de sintaxis Python" >&2
    FAIL=1
  fi
fi

if [[ "$FAIL" == "0" ]]; then
  echo "bt-script-test: OK"
  exit 0
fi
exit 1
