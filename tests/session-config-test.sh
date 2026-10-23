#!/usr/bin/env bash
# Pruebas de la auditoría de configuración para CVE-2026-115560.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-session-config-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

SCRIPT="$REPO_DIR/scripts/php2shell-session-config.sh"
FAIL=0

run_audit() {
  bash "$SCRIPT" --summary "$1" 2>&1
}

# 1. Combinación vulnerable: FLAG.
VULN="$TMP/vuln"
mkdir -p "$VULN/app"
printf 'session.serialize_handler = php_serialize\nsession.upload_progress.enabled = On\n' > "$VULN/php.ini"
cat > "$VULN/app/bootstrap.php" <<'PHP'
<?php
ini_set('session.serialize_handler', 'php');
session_start();
PHP
OUT="$(run_audit "$VULN")"
CODE=$?
if [[ "$CODE" == "2" && "$OUT" == *"Veredicto: FLAG"* ]]; then
  echo "[ok] combinación vulnerable -> FLAG"
else
  echo "[FAIL] combinación vulnerable (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi
LINES="$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
if [[ "$LINES" -le 12 ]]; then
  echo "[ok] resumen compacto: $LINES líneas"
else
  echo "[FAIL] resumen demasiado largo: $LINES líneas" >&2
  FAIL=1
fi

# 2. Upload progress desactivado: WARN, no FLAG.
MIT="$TMP/mitigated"
mkdir -p "$MIT/app"
printf 'session.serialize_handler = php_serialize\nsession.upload_progress.enabled = Off\n' > "$MIT/php.ini"
cp "$VULN/app/bootstrap.php" "$MIT/app/bootstrap.php"
OUT="$(run_audit "$MIT")"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" == *"Veredicto: WARN"* ]]; then
  echo "[ok] upload_progress Off -> WARN"
else
  echo "[FAIL] upload_progress Off (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 3. Serializer consistente: OK.
SAFE="$TMP/safe"
mkdir -p "$SAFE/app"
printf 'session.serialize_handler = php\nsession.upload_progress.enabled = On\n' > "$SAFE/php.ini"
printf '<?php\nsession_start();\n' > "$SAFE/app/index.php"
OUT="$(run_audit "$SAFE")"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" == *"Veredicto: OK"* ]]; then
  echo "[ok] serializer consistente -> OK"
else
  echo "[FAIL] serializer consistente (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 4. Sin archivos relevantes: UNKNOWN.
EMPTY="$TMP/empty"
mkdir -p "$EMPTY"
OUT="$(run_audit "$EMPTY")"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" == *"Veredicto: UNKNOWN"* ]]; then
  echo "[ok] sin evidencia -> UNKNOWN"
else
  echo "[FAIL] sin evidencia (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 5. Cambio en tiempo de ejecución sin config base: WARN, no FLAG.
NOSERIAL="$TMP/noserial"
mkdir -p "$NOSERIAL/app"
printf '<?php\nini_set("session.serialize_handler", "php");\nsession_start();\n' > "$NOSERIAL/app/bootstrap.php"
OUT="$(run_audit "$NOSERIAL")"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" == *"Veredicto: WARN"* ]]; then
  echo "[ok] sin base conocida -> WARN"
else
  echo "[FAIL] sin base conocida (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 6. Cambio después de session_start(): WARN, no FLAG.
AFTER="$TMP/after"
mkdir -p "$AFTER/app"
printf 'session.serialize_handler = php_serialize\nsession.upload_progress.enabled = On\n' > "$AFTER/php.ini"
printf '<?php\nsession_start();\nini_set("session.serialize_handler", "php");\n' > "$AFTER/app/bootstrap.php"
OUT="$(run_audit "$AFTER")"
CODE=$?
if [[ "$CODE" == "0" && "$OUT" == *"Veredicto: WARN"* ]]; then
  echo "[ok] cambio después de session_start -> WARN"
else
  echo "[FAIL] cambio después de session_start (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "session-config-test: OK"
  exit 0
fi
exit 1
