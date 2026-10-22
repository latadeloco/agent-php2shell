#!/usr/bin/env bash
# Desinstalador de php2shell-agent.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"
php2shell_init_paths

TARGET_SPEC="all"
PROJECT=0
PURGE=0
DRY_RUN=0
ASSUME_YES=0
TARGETS=()

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

  --target LIST   all | opencode,claude-code,codex,gemini,generic
  --project       Desinstala del proyecto actual
  --purge         Borra también datos, scanner, triaje e informes
  --dry-run       Muestra qué haría sin borrar nada
  --yes           No pide confirmación
  -h, --help      Esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "Falta el valor de --target"
      TARGET_SPEC="$2"
      shift 2
      ;;
    --target=*)
      TARGET_SPEC="${1#--target=}"
      shift
      ;;
    --project) PROJECT=1; shift ;;
    --purge) PURGE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
done

export ASSUME_YES

valid_target() {
  case "$1" in
    opencode|claude-code|codex|gemini|generic) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_targets() {
  local t
  case "$TARGET_SPEC" in
    all) TARGETS=(opencode claude-code codex gemini generic) ;;
    *)
      local IFS=','
      local -a parts
      read -ra parts <<< "$TARGET_SPEC"
      for t in "${parts[@]}"; do
        [[ -n "$t" ]] || continue
        valid_target "$t" || die "Target no válido: $t"
        TARGETS+=("$t")
      done
      ;;
  esac
}

dest_for() {
  local target="$1"
  case "$target" in
    opencode)
      if [[ "$PROJECT" == "1" ]]; then
        printf '%s/.opencode/agents/php2shell.md' "$PWD"
      else
        printf '%s/opencode/agents/php2shell.md' "$CONFIG_DIR"
      fi
      ;;
    claude-code)
      if [[ "$PROJECT" == "1" ]]; then
        printf '%s/.claude/agents/php2shell.md' "$PWD"
      else
        printf '%s/.claude/agents/php2shell.md' "$HOME"
      fi
      ;;
    codex)
      if [[ "$PROJECT" == "1" ]]; then
        printf '%s/.codex/agents/php2shell.toml' "$PWD"
      else
        printf '%s/.codex/agents/php2shell.toml' "$HOME"
      fi
      ;;
    gemini)
      if [[ "$PROJECT" == "1" ]]; then
        printf '%s/.gemini/commands/php2shell.toml' "$PWD"
      else
        printf '%s/.gemini/commands/php2shell.toml' "$HOME"
      fi
      ;;
    generic)
      printf '%s/AGENTS.md' "$PWD"
      ;;
  esac
}

remove_file() {
  local file="$1"
  if [[ -e "$file" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "Borraría: $file"
    else
      rm -f "$file"
      ok "Borrado: $file"
    fi
  fi
}

remove_agents_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if [[ "$DRY_RUN" == "1" ]]; then
    info "Quitaría el bloque php2shell de: $file"
    return 0
  fi
  remove_marked_block "$file" "<!-- php2shell-agent:begin -->" "<!-- php2shell-agent:end -->"
  if ! grep -q '[^[:space:]]' "$file"; then
    rm -f "$file"
  fi
  ok "Bloque eliminado de: $file"
}

resolve_targets

hr
info "${C_BOLD}Desinstalación de php2shell-agent${C_RESET}"
hr
for t in "${TARGETS[@]}"; do
  info "  $t -> $(dest_for "$t")"
done
if [[ "$PURGE" == "1" ]]; then
  info "  purge -> $DATA_DIR y $STATE_DIR"
fi
hr

if [[ "$DRY_RUN" != "1" ]] && ! confirm "¿Desinstalar ahora? [s/N] "; then
  info "Cancelado."
  exit 0
fi

for t in "${TARGETS[@]}"; do
  dest="$(dest_for "$t")"
  case "$t" in
    generic)
      remove_agents_block "$dest"
      ;;
    *)
      remove_file "$dest"
      ;;
  esac
done

remove_file "$TOOLS_DIR/preflight.sh"
remove_file "$TOOLS_DIR/php2shell-scan.sh"
remove_file "$TOOLS_DIR/php2shell-triage.sh"
remove_file "$TOOLS_DIR/lib.sh"

if [[ "$PURGE" == "1" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    info "Borraría: $DATA_DIR"
    info "Borraría: $STATE_DIR"
  else
    rm -rf "$DATA_DIR" "$STATE_DIR"
    ok "Datos e informes eliminados"
  fi
else
  info "Se conservan el scanner, el triaje y los informes."
  info "Usa --purge para borrarlos."
fi

hr
info "${C_GREEN}Desinstalación completada.${C_RESET}"
