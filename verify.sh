#!/usr/bin/env bash
# Verificación local del repositorio y de la instalación.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"
php2shell_init_paths

FAIL=0

hr
info "${C_BOLD}Verificación de php2shell-agent${C_RESET}"
hr

info "1. Sintaxis de scripts"
while IFS= read -r -d '' file; do
  if bash -n "$file"; then
    ok "$file"
  else
    err "Error de sintaxis: $file"
    FAIL=1
  fi
done < <(find "$REPO_DIR" -name '*.sh' -print0)

info ""
info "2. Tests del repositorio"
for test in "$REPO_DIR/tests/render-test.sh" \
            "$REPO_DIR/tests/preflight-test.sh" \
            "$REPO_DIR/tests/wrapper-test.sh"; do
  if [[ -f "$test" ]]; then
    if bash "$test"; then
      ok "$(basename "$test")"
    else
      err "Falló $(basename "$test")"
      FAIL=1
    fi
  fi
done

info ""
info "3. Preflight"
if [[ -f "$TOOLS_DIR/preflight.sh" ]]; then
  if "$TOOLS_DIR/preflight.sh" --check; then
    ok "preflight de la instalación"
  else
    err "El preflight de la instalación ha fallado"
    FAIL=1
  fi
else
  if "$REPO_DIR/scripts/php2shell-preflight.sh" --bootstrap; then
    ok "preflight de bootstrap (aún no instalado)"
  else
    err "El preflight de bootstrap ha fallado"
    FAIL=1
  fi
fi

info ""
info "4. Agente en opencode"
if have_cmd opencode; then
  if opencode agent list 2>/dev/null | grep -q '^php2shell'; then
    ok "php2shell aparece en opencode"
  else
    warn "php2shell no aparece en 'opencode agent list'"
  fi
else
  info "opencode no está instalado; se omite."
fi

info ""
info "5. Sin rutas personales ni placeholders en adaptadores renderizados"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-verify.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export MODEL_LINE=""
for adapter in "$REPO_DIR/adapters/opencode/php2shell.md" \
               "$REPO_DIR/adapters/claude-code/php2shell.md" \
               "$REPO_DIR/adapters/codex/php2shell.md" \
               "$REPO_DIR/adapters/generic/AGENTS.md"; do
  name="$(basename "$(dirname "$adapter")")"
  render_adapter "$REPO_DIR/core/prompt.md" "$adapter" "$TMP/$name"
  if grep -qE '@@[A-Z_]+@@' "$TMP/$name"; then
    err "Placeholder sin sustituir en $name"
    FAIL=1
  else
    ok "$name sin placeholders"
  fi
done
if grep -rq '/home/jesus' "$REPO_DIR/core" "$REPO_DIR/adapters" "$REPO_DIR/scripts" 2>/dev/null; then
  err "Hay rutas personales en el repositorio"
  FAIL=1
else
  ok "sin rutas personales"
fi

hr
if [[ "$FAIL" == "0" ]]; then
  info "${C_GREEN}Verificación correcta.${C_RESET}"
  exit 0
fi
info "${C_RED}Verificación con errores.${C_RESET}"
exit 1
