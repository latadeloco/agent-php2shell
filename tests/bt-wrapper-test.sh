#!/usr/bin/env bash
# Pruebas del wrapper del módulo avanzado php2shellbt.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-bt-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/data"
TOOLS="$DATA/tools"
VENDOR="$TOOLS/vendor"
STATE="$TMP/state"
BIN="$TMP/bin"

mkdir -p "$TOOLS" "$VENDOR" "$STATE" "$BIN"
cp "$REPO_DIR/scripts/php2shell-bt.sh" "$TOOLS/php2shell-bt.sh"
cp "$REPO_DIR/scripts/lib.sh" "$TOOLS/lib.sh"
touch "$VENDOR/php2shellbt.py"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TOOLS/preflight.sh"
chmod +x "$TOOLS/preflight.sh"

# Python falso: si se invoca el script, emite JSON y sale 1 (vulnerable).
# Si se invoca el resumen ("-"), imprime una línea de resumen.
cat > "$BIN/python3" <<'PY'
#!/usr/bin/env bash
if [[ "${1:-}" == "-" ]]; then
  echo "- Avisos de sesión: VULNERABLE"
  exit 0
fi
cat > /dev/null
printf '{"target":"http://example.com","results":{"cve109618_warn":"VULNERABLE"}}\n'
exit 1
PY
chmod +x "$BIN/python3"

FAIL=0
run_bt() {
  env PHP2SHELL_DATA_DIR="$DATA" PHP2SHELL_STATE_DIR="$STATE" \
    PATH="$BIN:/usr/bin:/bin" bash "$TOOLS/php2shell-bt.sh" "$@"
}

# 1. Sin autorización debe negarse con código 3.
if run_bt -u http://example.com >/dev/null 2>&1; then
  echo "[FAIL] debería negarse sin --i-have-permission" >&2
  FAIL=1
else
  code=$?
  [[ "$code" == "3" ]] && echo "[ok] sin autorización -> código 3" || { echo "[FAIL] código $code" >&2; FAIL=1; }
fi

# 2. Dry-run por defecto: solo warn.
OUT="$(run_bt --dry-run -u http://example.com 2>&1)"
if [[ "$OUT" == *"php2shellbt.py"* && "$OUT" == *"--checks warn"* ]]; then
  echo "[ok] dry-run por defecto"
else
  echo "[FAIL] dry-run por defecto" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 3. --advanced sin rutas debe fallar.
if run_bt --dry-run --advanced -u http://example.com >/dev/null 2>&1; then
  echo "[FAIL] --advanced sin rutas debería fallar" >&2
  FAIL=1
else
  echo "[ok] --advanced sin rutas -> error"
fi

# 4. Rechazo de listas.
if run_bt --dry-run -u http://example.com --targets lista.txt >/dev/null 2>&1; then
  echo "[FAIL] --targets debería rechazarse" >&2
  FAIL=1
else
  echo "[ok] --targets rechazado"
fi

# 5. handler sin rutas debe fallar.
if run_bt --dry-run --checks handler -u http://example.com >/dev/null 2>&1; then
  echo "[FAIL] handler sin rutas debería fallar" >&2
  FAIL=1
else
  echo "[ok] handler sin rutas -> error"
fi

# 6. --advanced con rutas: checks warn,handler,lfi.
OUT="$(run_bt --dry-run --advanced -u http://example.com \
  --lfi '/vuln.php?page=' --write-path /upload.php --read-path /api/data.php 2>&1)"
if [[ "$OUT" == *"warn"* && "$OUT" == *"handler"* && "$OUT" == *"lfi"* ]]; then
  echo "[ok] --advanced activa warn,handler,lfi"
else
  echo "[FAIL] --advanced no activa los checks esperados" >&2
  FAIL=1
fi

# 7. Ejecución simulada: JSON guardado y resumen.
run_bt --i-have-permission -u http://example.com --checks warn > "$TMP/out.txt" 2>&1
code=$?
if [[ "$code" == "1" && -f "$(find "$STATE" -name '*-bt-*.json' | head -n1)" ]]; then
  echo "[ok] ejecución simulada: JSON y código 1"
else
  echo "[FAIL] ejecución simulada (código $code)" >&2
  cat "$TMP/out.txt" >&2
  FAIL=1
fi
if grep -q 'Avisos de sesión' "$TMP/out.txt"; then
  echo "[ok] resumen generado"
else
  echo "[FAIL] falta el resumen" >&2
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "bt-wrapper-test: OK"
  exit 0
fi
exit 1
