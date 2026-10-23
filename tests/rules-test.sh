#!/usr/bin/env bash
# Pruebas del wrapper de reglas de defensa.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-rules-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

DATA="$TMP/data"
TOOLS="$DATA/tools"
STATE="$TMP/state"
FIX="$TMP/fixtures"
BIN="$TMP/bin"

mkdir -p "$TOOLS" "$STATE" "$FIX" "$BIN"
cp "$REPO_DIR/scripts/php2shell-rules.sh" "$TOOLS/php2shell-rules.sh"
cp "$REPO_DIR/scripts/lib.sh" "$TOOLS/lib.sh"

hash_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

cat > "$FIX/php2shell.rules" <<'EOF'
# SID 2026100 — sample
alert http any any -> any any ( \
    msg:"PHP2SHELL sample post"; \
    sid:2026100; rev:1; \
)

# SID 2026105 — chunked
alert http any any -> any any ( \
    msg:"PHP2SHELL chunked"; \
    sid:2026105; rev:1; \
)
EOF

cat > "$FIX/modsecurity.conf" <<'EOF'
# --- Rule 9900100: block something ---
SecRule REQUEST_METHOD "POST" \
    "id:9900100, \
    phase:2, \
    deny, \
    status:403, \
    log"

# --- Rule 9900106: chunked multipart ---
SecRule REQUEST_METHOD "POST" \
    "id:9900106, \
    phase:1, \
    deny, \
    status:400, \
    log"

# --- Rule 9900101: alert only ---
SecRule REQUEST_BODY "@rx x" \
    "id:9900101, \
    phase:2, \
    pass, \
    log"
EOF

printf '# lua fixture\n' > "$FIX/php2shell.lua"
printf '# sigma fixture\n' > "$FIX/php2shell.yaml"

export PHP2SHELL_DATA_DIR="$DATA"
export PHP2SHELL_STATE_DIR="$STATE"
if command -v cygpath >/dev/null 2>&1; then
  export PHP2SHELL_RULES_RAW_BASE="file://$(cygpath -m "$FIX")"
else
  export PHP2SHELL_RULES_RAW_BASE="file://$FIX"
fi
export PHP2SHELL_RULES_SHA256_MODSECURITY="$(hash_of "$FIX/modsecurity.conf")"
export PHP2SHELL_RULES_SHA256_LUA="$(hash_of "$FIX/php2shell.lua")"
export PHP2SHELL_RULES_SHA256_RULES="$(hash_of "$FIX/php2shell.rules")"
export PHP2SHELL_RULES_SHA256_YAML="$(hash_of "$FIX/php2shell.yaml")"

FAIL=0
run() { bash "$TOOLS/php2shell-rules.sh" "$@"; }

# 1. Sin --install no escribe nada.
OUT="$(run --dest "$TMP/out-dry" 2>&1)"
CODE=$?
if [[ "$CODE" == "0" && ! -e "$TMP/out-dry" && "$OUT" == *"Modo simulación"* ]]; then
  echo "[ok] sin --install no escribe nada"
else
  echo "[FAIL] el modo simulación escribió o falló (código $CODE)" >&2
  FAIL=1
fi

# 2. Perfil alert: sin deny y sin la regla agresiva.
OUT="$(run --install --profile alert --dest "$TMP/alert" 2>&1)"
CODE=$?
if [[ "$CODE" == "0" && -f "$TMP/alert/modsecurity.conf" ]]; then
  if grep -q 'deny' "$TMP/alert/modsecurity.conf"; then
    echo "[FAIL] el perfil alert contiene 'deny'" >&2
    FAIL=1
  elif grep -q '9900106' "$TMP/alert/modsecurity.conf"; then
    echo "[FAIL] el perfil alert incluye la regla 9900106" >&2
    FAIL=1
  elif grep -q 'sid:2026105;' "$TMP/alert/php2shell.rules"; then
    echo "[FAIL] el perfil alert incluye el SID 2026105" >&2
    FAIL=1
  else
    echo "[ok] perfil alert sin bloqueo ni regla agresiva"
  fi
else
  echo "[FAIL] no se pudo instalar el perfil alert (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 3. Perfil block + agresiva: incluye deny y la regla.
OUT="$(run --install --profile block --include-aggressive --dest "$TMP/block" 2>&1)"
CODE=$?
if [[ "$CODE" == "0" && -f "$TMP/block/modsecurity.conf" ]]; then
  if grep -q 'deny' "$TMP/block/modsecurity.conf" \
     && grep -q '9900106' "$TMP/block/modsecurity.conf" \
     && grep -q 'sid:2026105;' "$TMP/block/php2shell.rules"; then
    echo "[ok] perfil block incluye deny y regla agresiva"
  else
    echo "[FAIL] el perfil block no incluye lo esperado" >&2
    FAIL=1
  fi
else
  echo "[FAIL] no se pudo instalar el perfil block (código $CODE)" >&2
  echo "$OUT" >&2
  FAIL=1
fi

# 4. Hash manipulado: debe fallar cerrado.
printf '# tampered\n' >> "$FIX/modsecurity.conf"
OUT="$(run --install --profile alert --dest "$TMP/tampered" 2>&1)"
CODE=$?
if [[ "$CODE" != "0" && ! -e "$TMP/tampered/modsecurity.conf" ]]; then
  echo "[ok] hash incorrecto -> falla cerrado"
else
  echo "[FAIL] un hash incorrecto no detuvo la instalación (código $CODE)" >&2
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "rules-test: OK"
  exit 0
fi
exit 1
