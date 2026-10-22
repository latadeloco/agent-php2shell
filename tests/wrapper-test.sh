#!/usr/bin/env bash
# Pruebas del bloqueo de seguridad y del --dry-run del wrapper de escaneo.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-wrapper-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/data"
TOOLS="$DATA/tools"
SCANNER="$DATA/scanner"
STATE="$TMP/state"
BIN="$TMP/bin"

mkdir -p "$TOOLS" "$SCANNER" "$STATE" "$BIN"
cp "$REPO_DIR/scripts/php2shell-scan.sh" "$TOOLS/php2shell-scan.sh"
cp "$REPO_DIR/scripts/lib.sh" "$TOOLS/lib.sh"
touch "$SCANNER/scanner.py"
printf '#!/usr/bin/env bash\nprintf "uv-fake %s\\n" "$*"\n' > "$BIN/uv"
chmod +x "$BIN/uv" "$TOOLS/php2shell-scan.sh"

FAIL=0

# 1. Sin --i-have-permission debe negarse con código 3.
if env PHP2SHELL_DATA_DIR="$DATA" PHP2SHELL_STATE_DIR="$STATE" PATH="$BIN:/usr/bin:/bin" \
  bash "$TOOLS/php2shell-scan.sh" -u http://example.com >/dev/null 2>&1; then
  echo "[FAIL] El wrapper debería negarse sin autorización" >&2
  FAIL=1
else
  code=$?
  if [[ "$code" == "3" ]]; then
    echo "[ok] sin autorización -> código 3"
  else
    echo "[FAIL] sin autorización -> código $code (esperado 3)" >&2
    FAIL=1
  fi
fi

# 2. --dry-run sin autorización debe funcionar y no ejecutar el scanner.
OUT="$(env PHP2SHELL_DATA_DIR="$DATA" PHP2SHELL_STATE_DIR="$STATE" PATH="$BIN:/usr/bin:/bin" \
  bash "$TOOLS/php2shell-scan.sh" --dry-run --no-preflight -u http://example.com 2>&1)"
code=$?
if [[ "$code" == "0" && "$OUT" == *"scanner.py"* && "$OUT" == *"http://example.com"* ]]; then
  echo "[ok] --dry-run muestra el comando y no ejecuta el scanner"
else
  echo "[FAIL] --dry-run inesperado (código $code)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 3. Con autorización y --dry-run debe seguir sin enviar tráfico.
OUT="$(env PHP2SHELL_DATA_DIR="$DATA" PHP2SHELL_STATE_DIR="$STATE" PATH="$BIN:/usr/bin:/bin" \
  bash "$TOOLS/php2shell-scan.sh" --dry-run --no-preflight --i-have-permission -u http://example.com 2>&1)"
if [[ "$OUT" == *"scanner.py"* ]]; then
  echo "[ok] --i-have-permission + --dry-run correcto"
else
  echo "[FAIL] --i-have-permission + --dry-run" >&2
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "wrapper-test: OK"
  exit 0
fi
exit 1
