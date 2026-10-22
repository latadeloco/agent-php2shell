#!/usr/bin/env bash
# Pruebas de la auditoría de sesión de solo lectura.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-session-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/data"
TOOLS="$DATA/tools"
STATE="$TMP/state"
TARGET="$TMP/project"
CLEAN_SESS="$TMP/clean-sessions"
BAD_SESS="$TMP/bad-sessions"
CLEAN_LOGS="$TMP/clean-logs"
BAD_LOGS="$TMP/bad-logs"

mkdir -p "$TOOLS" "$STATE" "$TARGET" "$CLEAN_SESS" "$BAD_SESS" "$CLEAN_LOGS" "$BAD_LOGS"
cp "$REPO_DIR/scripts/php2shell-session-audit.sh" "$TOOLS/php2shell-session-audit.sh"
cp "$REPO_DIR/scripts/lib.sh" "$TOOLS/lib.sh"

printf 'foo|s:6:"normal";' > "$CLEAN_SESS/sess_normal"
printf 'ok\n' > "$CLEAN_LOGS/php-fpm.log"

printf 'x|s:99:"<?php system($_GET[0]); ?>";' > "$BAD_SESS/sess_payload"
printf 'x|O:8:"stdClass":0:{}' > "$BAD_SESS/sess_object"
printf '2026-10-21 Session object destruction failed for /var/lib/php/sessions/sess_1\n' > "$BAD_LOGS/php-fpm.log"

export PHP2SHELL_DATA_DIR="$DATA"
export PHP2SHELL_STATE_DIR="$STATE"

FAIL=0
run() { bash "$TOOLS/php2shell-session-audit.sh" "$@"; }

# 1. Fixtures limpios: cero flags y salida limpia.
OUT="$(run --sessions-dir "$CLEAN_SESS" --log-dir "$CLEAN_LOGS" "$TARGET" 2>&1)"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" != *"[FLAG]"* && "$OUT" == *"0 flag(s)"* ]]; then
  echo "[ok] sesiones y logs limpios -> 0 flags"
else
  echo "[FAIL] un fixture limpio generó flags (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 2. Código PHP en fichero de sesión: FLAG.
OUT="$(run --sessions-dir "$BAD_SESS" --log-dir "$CLEAN_LOGS" "$TARGET" 2>&1)"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" == *"[FLAG]"* && "$OUT" == *"código PHP"* ]]; then
  echo "[ok] código PHP en sesión -> FLAG"
else
  echo "[FAIL] no se detectó el código PHP en la sesión (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 3. Objeto serializado en sesión: FLAG.
OUT="$(run --sessions-dir "$BAD_SESS" --log-dir "$CLEAN_LOGS" "$TARGET" 2>&1)"
if [[ "$OUT" == *"objeto serializado"* ]]; then
  echo "[ok] objeto serializado en sesión -> FLAG"
else
  echo "[FAIL] no se detectó el objeto serializado" >&2
  FAIL=1
fi

# 4. Log con fallo de destrucción de sesión: FLAG.
OUT="$(run --sessions-dir "$CLEAN_SESS" --log-dir "$BAD_LOGS" "$TARGET" 2>&1)"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" == *"[FLAG]"* && "$OUT" == *"destrucción de sesión"* ]]; then
  echo "[ok] fallo de destrucción de sesión -> FLAG"
else
  echo "[FAIL] no se detectó el fallo de destrucción (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 5. Modo --summary: solo flags y recuento.
OUT="$(run --summary --sessions-dir "$BAD_SESS" --log-dir "$CLEAN_LOGS" "$TARGET" 2>&1)"
if [[ "$OUT" == *"[FLAG]"* && "$OUT" == *"Auditoría de sesión:"* && "$OUT" != *"[info]"* ]]; then
  echo "[ok] --summary muestra flags y recuento"
else
  echo "[FAIL] --summary inesperado" >&2
  echo "$OUT" >&2
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "session-audit-test: OK"
  exit 0
fi
exit 1
