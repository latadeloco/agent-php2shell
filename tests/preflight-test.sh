#!/usr/bin/env bash
# Pruebas del preflight con un directorio de datos temporal.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-preflight-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/data"
TOOLS="$DATA/tools"
VENDOR="$TOOLS/vendor"
SCANNER="$DATA/scanner"
STATE="$TMP/state"
BIN="$TMP/bin"

mkdir -p "$TOOLS" "$VENDOR" "$SCANNER" "$STATE" "$BIN"
cp "$REPO_DIR/scripts/php2shell-preflight.sh" "$TOOLS/preflight.sh"
cp "$REPO_DIR/scripts/lib.sh" "$TOOLS/lib.sh"
touch "$TOOLS/php2shell-scan.sh" "$TOOLS/php2shell-triage.sh" "$SCANNER/scanner.py"
printf '#!/usr/bin/env bash\nprintf "uv 0.0.0-test\\n"\n' > "$BIN/uv"
chmod +x "$BIN/uv" "$TOOLS/preflight.sh"

FAIL=0

run_preflight() {
  env \
    PHP2SHELL_DATA_DIR="$DATA" \
    PHP2SHELL_STATE_DIR="$STATE" \
    PATH="$1" \
    bash "$TOOLS/preflight.sh" "${@:2}"
}

# 1. Bootstrap sin uv: debe fallar con código 1.
if run_preflight "/usr/bin:/bin" --bootstrap >/dev/null 2>&1; then
  echo "[FAIL] Sin uv el preflight debería fallar" >&2
  FAIL=1
else
  code=$?
  if [[ "$code" == "1" ]]; then
    echo "[ok] sin uv -> código 1"
  else
    echo "[FAIL] sin uv -> código $code (esperado 1)" >&2
    FAIL=1
  fi
fi

# 2. Bootstrap con uv falso: debe pasar.
if run_preflight "$BIN:/usr/bin:/bin" --bootstrap >/dev/null 2>&1; then
  echo "[ok] bootstrap con uv -> código 0"
else
  echo "[FAIL] bootstrap con uv debería pasar" >&2
  FAIL=1
fi

# 2b. --brief debe producir un resumen de pocas líneas.
BRIEF_OUT="$(run_preflight "$BIN:/usr/bin:/bin" --bootstrap --brief 2>&1)"
BRIEF_LINES="$(printf '%s\n' "$BRIEF_OUT" | wc -l | tr -d ' ')"
if [[ "$BRIEF_LINES" -le 3 ]]; then
  echo "[ok] --brief -> $BRIEF_LINES línea(s)"
else
  echo "[FAIL] --brief demasiado largo: $BRIEF_LINES líneas" >&2
  FAIL=1
fi

# 3. Hash del triaje alterado: debe fallar con código 2.
printf 'contenido alterado\n' > "$VENDOR/php2shell-triage.sh"
if env \
    PHP2SHELL_DATA_DIR="$DATA" \
    PHP2SHELL_STATE_DIR="$STATE" \
    PHP2SHELL_TRIAGE_SHA256="0000000000000000000000000000000000000000000000000000000000000000" \
    PATH="$BIN:/usr/bin:/bin" \
    bash "$TOOLS/preflight.sh" --check >/dev/null 2>&1; then
  echo "[FAIL] Un hash alterado debería fallar" >&2
  FAIL=1
else
  code=$?
  if [[ "$code" == "2" ]]; then
    echo "[ok] hash alterado -> código 2"
  else
    echo "[FAIL] hash alterado -> código $code (esperado 2)" >&2
    FAIL=1
  fi
fi

if [[ "$FAIL" == "0" ]]; then
  echo "preflight-test: OK"
  exit 0
fi
exit 1
