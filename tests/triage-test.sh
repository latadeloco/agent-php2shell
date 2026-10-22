#!/usr/bin/env bash
# Prueba el modo --summary del wrapper de triaje.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-triage-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/data"
TOOLS="$DATA/tools"
VENDOR="$TOOLS/vendor"
STATE="$TMP/state"
TARGET="$TMP/project"

mkdir -p "$TOOLS" "$VENDOR" "$STATE" "$TARGET"
cp "$REPO_DIR/scripts/php2shell-triage.sh" "$TOOLS/php2shell-triage.sh"
cp "$REPO_DIR/scripts/lib.sh" "$TOOLS/lib.sh"

cat > "$VENDOR/php2shell-triage.sh" <<'EOF'
#!/usr/bin/env bash
echo "== 1. Sección larga =="
echo "  [FLAG] archivo sospechoso"
echo "  [warn] aviso menor"
echo "== Verdict =="
echo "1 flag(s) and 1 warning(s)."
echo "Treat this host as suspect."
EOF
chmod +x "$VENDOR/php2shell-triage.sh"

if command -v sha256sum >/dev/null 2>&1; then
  HASH="$(sha256sum "$VENDOR/php2shell-triage.sh" | awk '{print $1}')"
else
  HASH="$(shasum -a 256 "$VENDOR/php2shell-triage.sh" | awk '{print $1}')"
fi

OUT="$(env \
  PHP2SHELL_DATA_DIR="$DATA" \
  PHP2SHELL_STATE_DIR="$STATE" \
  PHP2SHELL_TRIAGE_SHA256="$HASH" \
  bash "$TOOLS/php2shell-triage.sh" --summary "$TARGET" 2>&1)"
CODE=$?

FAIL=0
if [[ "$CODE" != "0" ]]; then
  echo "[FAIL] el triaje terminó con código $CODE" >&2
  FAIL=1
fi
if [[ "$OUT" == *"[FLAG] archivo sospechoso"* ]]; then
  echo "[ok] el resumen incluye el FLAG"
else
  echo "[FAIL] el resumen no incluye el FLAG" >&2
  FAIL=1
fi
if [[ "$OUT" == *"== Verdict =="* ]]; then
  echo "[ok] el resumen incluye el veredicto"
else
  echo "[FAIL] el resumen no incluye el veredicto" >&2
  FAIL=1
fi
if [[ "$OUT" == *"== 1. Sección larga =="* ]]; then
  echo "[FAIL] el resumen incluye la sección larga" >&2
  FAIL=1
else
  echo "[ok] el resumen filtra la sección larga"
fi
if compgen -G "$STATE/*-triage-*.txt" >/dev/null; then
  echo "[ok] se guarda el informe completo"
else
  echo "[FAIL] no se guardó el informe completo" >&2
  FAIL=1
fi
LINES="$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
if [[ "$LINES" -le 15 ]]; then
  echo "[ok] resumen compacto: $LINES líneas"
else
  echo "[FAIL] resumen demasiado largo: $LINES líneas" >&2
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "triage-test: OK"
  exit 0
fi
exit 1
