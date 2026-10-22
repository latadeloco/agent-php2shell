#!/usr/bin/env bash
# Comprueba que todos los adaptadores renderizan sin placeholders ni rutas personales.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-render-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

export PHP2SHELL_DATA_DIR="$TMP/data"
export PHP2SHELL_STATE_DIR="$TMP/state"
php2shell_init_paths
export MODEL_LINE="model: test/model"
export MODEL_TOML_LINE='model = "test/model"'

FAIL=0

render_and_check() {
  local name="$1"
  local adapter="$2"
  local out="$TMP/$name.md"
  render_adapter "$REPO_DIR/core/prompt.md" "$adapter" "$out"
  if grep -qE '@@[A-Z_]+@@' "$out"; then
    echo "[FAIL] $name: placeholders sin sustituir" >&2
    FAIL=1
  else
    echo "[ok] $name: sin placeholders"
  fi
  if grep -q '/home/' "$out"; then
    echo "[FAIL] $name: ruta personal detectada" >&2
    FAIL=1
  else
    echo "[ok] $name: sin rutas personales"
  fi
  for source in Assetnote Sairahcaz Calif; do
    if ! grep -q "$source" "$out"; then
      echo "[FAIL] $name: falta el crédito a $source" >&2
      FAIL=1
    fi
  done
}

render_and_check "opencode" "$REPO_DIR/adapters/opencode/php2shell.md"
render_and_check "claude-code" "$REPO_DIR/adapters/claude-code/php2shell.md"
render_and_check "codex" "$REPO_DIR/adapters/codex/php2shell.toml"
render_and_check "generic" "$REPO_DIR/adapters/generic/AGENTS.md"

# Gemini usa TOML; el mismo renderizador debe sustituir los placeholders.
render_adapter "$REPO_DIR/core/prompt.md" "$REPO_DIR/adapters/gemini/php2shell.toml" "$TMP/gemini.toml"
if grep -qE '@@[A-Z_]+@@' "$TMP/gemini.toml"; then
  echo "[FAIL] gemini: placeholders sin sustituir" >&2
  FAIL=1
else
  echo "[ok] gemini: sin placeholders"
fi
if ! grep -q '^prompt = ' "$TMP/gemini.toml"; then
  echo "[FAIL] gemini: falta prompt TOML" >&2
  FAIL=1
fi

# Comprobaciones específicas de cada adaptador.
grep -q 'question: allow' "$TMP/opencode.md" || { echo "[FAIL] opencode sin question: allow" >&2; FAIL=1; }
grep -q 'edit: deny' "$TMP/opencode.md" || { echo "[FAIL] opencode sin edit: deny" >&2; FAIL=1; }
grep -q 'tools: Bash, Read, Glob, Grep' "$TMP/claude-code.md" || { echo "[FAIL] claude sin allowlist" >&2; FAIL=1; }
grep -q 'permissionMode: default' "$TMP/claude-code.md" || { echo "[FAIL] claude sin permissionMode" >&2; FAIL=1; }
grep -q 'model: test/model' "$TMP/opencode.md" || { echo "[FAIL] opencode sin modelo" >&2; FAIL=1; }
grep -q 'php2shell-scan.sh' "$TMP/opencode.md" || { echo "[FAIL] opencode sin wrapper de escaneo" >&2; FAIL=1; }
grep -q '^name = "php2shell"' "$TMP/codex.md" || { echo "[FAIL] codex sin name TOML" >&2; FAIL=1; }
grep -q '^developer_instructions = ' "$TMP/codex.md" || { echo "[FAIL] codex sin developer_instructions" >&2; FAIL=1; }
grep -q '^model = "test/model"' "$TMP/codex.md" || { echo "[FAIL] codex sin modelo TOML" >&2; FAIL=1; }

if grep -q '/home/jesus' "$REPO_DIR/core" "$REPO_DIR/adapters" "$REPO_DIR/scripts" 2>/dev/null; then
  echo "[FAIL] El repositorio contiene rutas personales" >&2
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "render-test: OK"
  exit 0
fi
exit 1
