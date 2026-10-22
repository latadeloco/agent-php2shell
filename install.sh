#!/usr/bin/env bash
# Instalador de php2shell-agent.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"
php2shell_init_paths

TARGET_SPEC="auto"
PROJECT=0
MODEL=""
DRY_RUN=0
ASSUME_YES=0
FORCE=0
TARGETS=()

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

  --target LIST   auto | all | opencode,claude-code,codex,gemini,generic
  --project       Instala en el proyecto actual en vez de global
  --model ID      Fija el modelo del agente (por defecto hereda el del host)
  --dry-run       Muestra el plan y no escribe nada
  --yes           No pide confirmación
  --force         Sobrescribe sin crear backup
  -h, --help      Esta ayuda

Ejemplos:
  ./install.sh
  ./install.sh --target opencode --model deepseek/deepseek-flash
  ./install.sh --target all --project
  ./install.sh --dry-run
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
    --model)
      [[ $# -ge 2 ]] || die "Falta el valor de --model"
      MODEL="$2"
      shift 2
      ;;
    --model=*)
      MODEL="${1#--model=}"
      shift
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --force) FORCE=1; shift ;;
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
    auto)
      for t in opencode claude-code codex gemini; do
        case "$t" in
          opencode) have_cmd opencode && TARGETS+=("$t") ;;
          claude-code) have_cmd claude && TARGETS+=("$t") ;;
          codex) have_cmd codex && TARGETS+=("$t") ;;
          gemini) have_cmd gemini && TARGETS+=("$t") ;;
        esac
      done
      if [[ ${#TARGETS[@]} -eq 0 ]]; then
        TARGETS+=(generic)
      fi
      ;;
    all)
      TARGETS=(opencode claude-code codex gemini generic)
      ;;
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
  [[ ${#TARGETS[@]} -gt 0 ]] || die "No hay targets que instalar."
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

print_plan() {
  hr
  info "${C_BOLD}php2shell-agent${C_RESET}"
  hr
  info "Datos:       $DATA_DIR"
  info "Herramientas: $TOOLS_DIR"
  info "Informes:    $STATE_DIR"
  info "Scanner:     $SCANNER_DIR"
  info "Commit:      $PHP2SHELL_SCANNER_COMMIT"
  info "Triaje:      $PHP2SHELL_TRIAGE_REV"
  info "Hash:        $PHP2SHELL_TRIAGE_SHA256"
  if [[ -n "$MODEL" ]]; then
    info "Modelo:      $MODEL"
  else
    info "Modelo:      heredado del host"
  fi
  info ""
  info "Destinos:"
  local t
  for t in "${TARGETS[@]}"; do
    info "  $t -> $(dest_for "$t")"
  done
  hr
}

install_adapter() {
  local target="$1"
  local dest="$2"
  local adapter="$3"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" && "$FORCE" != "1" ]]; then
    backup_file "$dest"
  fi
  render_adapter "$REPO_DIR/core/prompt.md" "$adapter" "$dest"
  chmod 0644 "$dest"
  ok "$target -> $dest"
}

install_agents_block() {
  local target="$1"
  local dest="$2"
  local adapter="$3"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/php2shell-block-render.XXXXXX")"
  render_adapter "$REPO_DIR/core/prompt.md" "$adapter" "$tmp"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" && "$FORCE" != "1" ]]; then
    backup_file "$dest"
  fi
  install_marked_block "$dest" "$tmp" "<!-- php2shell-agent:begin -->" "<!-- php2shell-agent:end -->"
  rm -f "$tmp"
  ok "$target -> $dest (bloque AGENTS.md)"
}

install_scanner() {
  mkdir -p "$DATA_DIR"
  if [[ -d "$SCANNER_DIR/.git" ]]; then
    info "Actualizando scanner..."
    git -C "$SCANNER_DIR" fetch --quiet origin || die "No se pudo actualizar el scanner."
  elif [[ -e "$SCANNER_DIR" ]]; then
    die "$SCANNER_DIR existe pero no es un repositorio git. Muévelo o bórralo."
  else
    info "Clonando scanner de Assetnote..."
    git clone --quiet "$PHP2SHELL_SCANNER_REPO" "$SCANNER_DIR" || die "No se pudo clonar el scanner."
  fi
  git -C "$SCANNER_DIR" checkout --quiet "$PHP2SHELL_SCANNER_COMMIT" \
    || die "No se pudo cambiar al commit fijado del scanner."
  local actual
  actual="$(git -C "$SCANNER_DIR" rev-parse HEAD)"
  [[ "$actual" == "$PHP2SHELL_SCANNER_COMMIT" ]] \
    || die "El scanner quedó en un commit inesperado: $actual"
  ok "scanner en $PHP2SHELL_SCANNER_COMMIT"
}

install_triage() {
  mkdir -p "$VENDOR_DIR"
  local tmp="$VENDOR_DIR/php2shell-triage.sh.tmp"
  info "Descargando script de triaje de Sairahcaz..."
  curl -fsSL "$PHP2SHELL_TRIAGE_URL" -o "$tmp" || die "No se pudo descargar el triaje."
  local actual
  actual="$(sha256_of "$tmp")"
  if [[ "$actual" != "$PHP2SHELL_TRIAGE_SHA256" ]]; then
    rm -f "$tmp"
    die "El SHA-256 del triaje no coincide. Esperado: $PHP2SHELL_TRIAGE_SHA256. Obtenido: $actual"
  fi
  chmod 0755 "$tmp"
  mv "$tmp" "$VENDOR_DIR/php2shell-triage.sh"
  ok "triaje verificado ($actual)"
}

install_tools() {
  mkdir -p "$TOOLS_DIR" "$DATA_DIR"
  cp "$REPO_DIR/scripts/php2shell-preflight.sh" "$TOOLS_DIR/preflight.sh"
  cp "$REPO_DIR/scripts/php2shell-scan.sh" "$TOOLS_DIR/php2shell-scan.sh"
  cp "$REPO_DIR/scripts/php2shell-triage.sh" "$TOOLS_DIR/php2shell-triage.sh"
  cp "$REPO_DIR/scripts/php2shell-rules.sh" "$TOOLS_DIR/php2shell-rules.sh"
  cp "$REPO_DIR/scripts/php2shell-session-audit.sh" "$TOOLS_DIR/php2shell-session-audit.sh"
  cp "$REPO_DIR/scripts/lib.sh" "$TOOLS_DIR/lib.sh"
  cp "$REPO_DIR/SOURCES.md" "$DATA_DIR/SOURCES.md"
  cp "$REPO_DIR/LICENSE" "$DATA_DIR/LICENSE"
  chmod 0755 "$TOOLS_DIR/preflight.sh" "$TOOLS_DIR/php2shell-scan.sh" "$TOOLS_DIR/php2shell-triage.sh" \
    "$TOOLS_DIR/php2shell-rules.sh" "$TOOLS_DIR/php2shell-session-audit.sh"
  chmod 0644 "$TOOLS_DIR/lib.sh" "$DATA_DIR/SOURCES.md" "$DATA_DIR/LICENSE"
  mkdir -p "$STATE_DIR"
  ok "wrappers instalados en $TOOLS_DIR"
}

render_targets() {
  local t dest
  local -a done_dests=()
  local d already
  for t in "${TARGETS[@]}"; do
    dest="$(dest_for "$t")"
    already=0
    for d in "${done_dests[@]}"; do
      [[ "$d" == "$dest" ]] && already=1
    done
    if [[ "$already" == "1" ]]; then
      info "  $t -> $dest (ya cubierto por otro target)"
      continue
    fi
    done_dests+=("$dest")
    case "$t" in
      opencode)
        install_adapter "$t" "$dest" "$REPO_DIR/adapters/opencode/php2shell.md"
        ;;
      claude-code)
        if [[ -n "$MODEL" && "$MODEL" == */* ]]; then
          warn "Claude Code espera alias (sonnet/opus/haiku) o ID de Claude; '$MODEL' puede no ser válido."
        fi
        install_adapter "$t" "$dest" "$REPO_DIR/adapters/claude-code/php2shell.md"
        ;;
      codex)
        install_adapter "$t" "$dest" "$REPO_DIR/adapters/codex/php2shell.toml"
        ;;
      gemini)
        if [[ -n "$MODEL" ]]; then
          warn "Gemini usa el modelo configurado en la CLI; --model no se aplica a este target."
        fi
        install_adapter "$t" "$dest" "$REPO_DIR/adapters/gemini/php2shell.toml"
        ;;
      generic)
        install_agents_block "$t" "$dest" "$REPO_DIR/adapters/generic/AGENTS.md"
        ;;
    esac
  done
}

resolve_targets

if [[ -n "$MODEL" ]]; then
  if [[ "$MODEL" == *'"'* || "$MODEL" == *$'\n'* ]]; then
    die "El valor de --model no puede contener comillas ni saltos de línea."
  fi
  export MODEL_LINE="model: $MODEL"
  export MODEL_TOML_LINE="model = \"$MODEL\""
else
  export MODEL_LINE=""
  export MODEL_TOML_LINE=""
fi

print_plan

if ! have_cmd uv; then
  err "Falta 'uv', la herramienta que ejecuta el scanner."
  info "Instálalo con: curl -LsSf https://astral.sh/uv/install.sh | sh"
  info "Después vuelve a ejecutar ./install.sh --yes"
  exit 1
fi

if ! "$REPO_DIR/scripts/php2shell-preflight.sh" --bootstrap; then
  die "Faltan dependencias obligatorias. No se ha instalado nada."
fi

if [[ "$DRY_RUN" == "1" ]]; then
  info ""
  info "Modo --dry-run: no se ha escrito nada."
  exit 0
fi

if ! confirm "¿Instalar php2shell-agent ahora? [s/N] "; then
  info "Cancelado. No se ha escrito nada."
  exit 0
fi

install_scanner
install_triage
install_tools
render_targets

info ""
if ! "$TOOLS_DIR/preflight.sh" --check --quiet; then
  warn "La instalación ha terminado, pero el preflight ha encontrado avisos."
  warn "Ejecuta '$TOOLS_DIR/preflight.sh --check' para verlos."
fi

hr
info "${C_GREEN}Instalación completada.${C_RESET}"
info ""
info "Cómo usarlo:"
for t in "${TARGETS[@]}"; do
  case "$t" in
    opencode) info "  opencode:  selecciona 'php2shell' con Tab o escribe @php2shell" ;;
    claude-code) info "  Claude Code: usa el subagente php2shell desde /agents" ;;
    codex) info "  Codex:     pide al subagente php2shell por su nombre" ;;
    gemini) info "  Gemini:    invoca /php2shell" ;;
    generic) info "  Genérico:  el bloque está en $(dest_for "$t")" ;;
  esac
done
info ""
info "Recuerda: la prueba activa solo debe usarse con autorización."
info "Fuentes: Assetnote, Sairahcaz y Calif. Ver $DATA_DIR/SOURCES.md"
