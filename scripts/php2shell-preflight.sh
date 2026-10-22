#!/usr/bin/env bash
# Revisión previa de solo lectura para php2shell-agent.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

MODE="check"
JSON=0
QUIET=0

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

  --check       Comprobación completa (por defecto)
  --bootstrap   Solo herramientas del sistema, antes de instalar
  --smoke       Comprobación completa + scanner.py --help
  --json        Salida JSON
  --quiet       No mostrar la tabla de comandos
  -h, --help    Esta ayuda

Códigos: 0 todo OK, 1 falta algo obligatorio, 2 integridad o permisos.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check" ;;
    --bootstrap) MODE="bootstrap" ;;
    --smoke) MODE="smoke" ;;
    --json) JSON=1 ;;
    --quiet) QUIET=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
  shift
done

REQUIRED=(bash git curl sha256sum uv)
OPTIONAL=(php opencode claude codex gemini)
STATUS=0
INTEGRITY=0

declare -a JSON_TOOLS=()
declare -a JSON_FILES=()
declare -a JSON_NOTES=()

record_tool() {
  local name="$1" path="$2" version="$3" required="$4"
  JSON_TOOLS+=("{\"name\":\"$(json_escape "$name")\",\"path\":\"$(json_escape "$path")\",\"version\":\"$(json_escape "$version")\",\"required\":$required}")
}

add_note() {
  JSON_NOTES+=("$(json_escape "$1")")
}

check_required_tools() {
  local name path version
  for name in "${REQUIRED[@]}"; do
    if have_cmd "$name"; then
      path="$(command -v "$name")"
      version=""
      case "$name" in
        bash) version="$(bash --version 2>/dev/null | head -n1)" ;;
        git) version="$(git --version 2>/dev/null)" ;;
        curl) version="$(curl --version 2>/dev/null | head -n1)" ;;
        sha256sum) version="$(sha256sum --version 2>/dev/null | head -n1)" ;;
        uv) version="$(uv --version 2>/dev/null)" ;;
      esac
      record_tool "$name" "$path" "$version" true
      [[ "$JSON" == "1" ]] || ok "$name: ${version:-disponible}"
    else
      record_tool "$name" "" "" true
      [[ "$JSON" == "1" ]] || err "Falta '$name' (obligatorio)."
      STATUS=1
      add_note "Falta la herramienta obligatoria $name"
    fi
  done
}

check_optional_tools() {
  local name path version
  for name in "${OPTIONAL[@]}"; do
    if have_cmd "$name"; then
      path="$(command -v "$name")"
      version=""
      case "$name" in
        php) version="$(php -v 2>/dev/null | head -n1)" ;;
        opencode) version="$(opencode --version 2>/dev/null)" ;;
        claude) version="$(claude --version 2>/dev/null | head -n1)" ;;
        codex) version="$(codex --version 2>/dev/null | head -n1)" ;;
        gemini) version="$(gemini --version 2>/dev/null | head -n1)" ;;
      esac
      record_tool "$name" "$path" "$version" false
      [[ "$JSON" == "1" ]] || ok "$name: ${version:-disponible}"
    else
      record_tool "$name" "" "" false
      [[ "$JSON" == "1" ]] || info " ${C_YELLOW}[--]${C_RESET} $name no encontrado (opcional)"
    fi
  done
}

check_file() {
  local label="$1" path="$2"
  if [[ -f "$path" ]]; then
    JSON_FILES+=("{\"label\":\"$(json_escape "$label")\",\"path\":\"$(json_escape "$path")\",\"ok\":true}")
    [[ "$JSON" == "1" ]] || ok "$label"
  else
    JSON_FILES+=("{\"label\":\"$(json_escape "$label")\",\"path\":\"$(json_escape "$path")\",\"ok\":false}")
    [[ "$JSON" == "1" ]] || err "Falta $label: $path"
    STATUS=1
    add_note "Falta $label"
  fi
}

check_integrity() {
  local actual
  check_file "scanner.py" "$SCANNER_DIR/scanner.py"
  check_file "triaje (gist)" "$VENDOR_DIR/php2shell-triage.sh"
  check_file "wrapper de escaneo" "$TOOLS_DIR/php2shell-scan.sh"
  check_file "wrapper de triaje" "$TOOLS_DIR/php2shell-triage.sh"
  check_file "preflight" "$TOOLS_DIR/preflight.sh"

  if [[ -f "$SCANNER_DIR/scanner.py" ]]; then
    if [[ -d "$SCANNER_DIR/.git" ]]; then
      actual="$(git -C "$SCANNER_DIR" rev-parse HEAD 2>/dev/null || true)"
      if [[ "$actual" == "$PHP2SHELL_SCANNER_COMMIT" ]]; then
        [[ "$JSON" == "1" ]] || ok "scanner en el commit fijado"
      else
        [[ "$JSON" == "1" ]] || err "scanner en commit inesperado: ${actual:-desconocido}"
        INTEGRITY=1
        add_note "El scanner no está en el commit fijado"
      fi
    else
      warn "scanner sin repositorio git; no puedo verificar el commit"
    fi
  fi

  if [[ -f "$VENDOR_DIR/php2shell-triage.sh" ]]; then
    actual="$(sha256_of "$VENDOR_DIR/php2shell-triage.sh")"
    if [[ "$actual" == "$PHP2SHELL_TRIAGE_SHA256" ]]; then
      [[ "$JSON" == "1" ]] || ok "triaje con SHA-256 correcto"
    else
      [[ "$JSON" == "1" ]] || err "SHA-256 del triaje incorrecto: $actual"
      INTEGRITY=1
      add_note "El script de triaje no coincide con el hash fijado"
    fi
  fi

  if [[ ! -d "$STATE_DIR" ]]; then
    if [[ -w "$(dirname "$STATE_DIR")" ]] || [[ -w "$(dirname "$(dirname "$STATE_DIR")")" ]]; then
      [[ "$JSON" == "1" ]] || warn "El directorio de informes no existe todavía: $STATE_DIR"
    else
      [[ "$JSON" == "1" ]] || err "No se puede escribir en el directorio de informes: $STATE_DIR"
      STATUS=1
      add_note "Directorio de informes no escribible"
    fi
  elif [[ ! -w "$STATE_DIR" ]]; then
    [[ "$JSON" == "1" ]] || err "El directorio de informes no es escribible: $STATE_DIR"
    STATUS=1
    add_note "Directorio de informes no escribible"
  fi
}

audit_opencode_agent() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local bad=0
  if grep -Eq '^[[:space:]]*edit:[[:space:]]*allow' "$file"; then
    err "El agente de opencode permite editar archivos."
    bad=1
  fi
  if grep -Eq '^[[:space:]]*webfetch:[[:space:]]*allow' "$file"; then
    err "El agente de opencode permite webfetch."
    bad=1
  fi
  if grep -Eq '^[[:space:]]*question:[[:space:]]*allow' "$file"; then
    [[ "$JSON" == "1" ]] || ok "permisos de opencode: sin edición, sin webfetch, question permitido"
  else
    warn "El agente de opencode no declara 'question: allow'."
  fi
  if [[ "$bad" == "1" ]]; then
    INTEGRITY=1
    add_note "Permisos inseguros en el agente de opencode"
  fi
}

audit_claude_agent() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if grep -Eq '^tools:.*(Write|Edit)' "$file"; then
    err "El agente de Claude Code permite Write/Edit."
    INTEGRITY=1
    add_note "Permisos inseguros en el agente de Claude Code"
  else
    [[ "$JSON" == "1" ]] || ok "permisos de Claude Code: sin Write/Edit"
  fi
}

audit_permissions() {
  local found=0
  local f
  for f in "$CONFIG_DIR/opencode/agents/php2shell.md" \
           "$PWD/.opencode/agents/php2shell.md"; do
    if [[ -f "$f" ]]; then
      found=1
      audit_opencode_agent "$f"
    fi
  done
  for f in "$HOME/.claude/agents/php2shell.md" \
           "$PWD/.claude/agents/php2shell.md"; do
    if [[ -f "$f" ]]; then
      found=1
      audit_claude_agent "$f"
    fi
  done
  if [[ "$found" == "0" ]]; then
    warn "No he encontrado un agente instalado en las rutas habituales."
    add_note "Agente no encontrado en rutas habituales"
  fi
}

print_commands() {
  [[ "$QUIET" == "1" ]] && return 0
  hr
  info "${C_BOLD}Comandos que puede usar el agente${C_RESET}"
  hr
  info "  preflight   $TOOLS_DIR/preflight.sh --check"
  info "              Solo lectura: comprueba herramientas, hashes y permisos."
  info "  escaneo     $TOOLS_DIR/php2shell-scan.sh --dry-run ..."
  info "              Prueba activa. Exige --i-have-permission. Escribe JSON."
  info "  triaje      $TOOLS_DIR/php2shell-triage.sh <ruta>"
  info "              Solo lectura del sistema. Escribe un informe .txt."
  info "  curl        curl -sS -D - -o /dev/null --max-time 20 ..."
  info "              Solo cabeceras. No escribe archivos."
  info "  php -v      Solo lectura."
  info "  sudo        Nunca lo ejecuta el agente; solo muestra el comando."
}

run_smoke() {
  [[ "$JSON" == "1" ]] && return 0
  info "Ejecutando prueba suave del scanner (scanner.py --help)..."
  if uv run --quiet "$SCANNER_DIR/scanner.py" --help >/dev/null 2>&1; then
    ok "scanner.py responde correctamente"
  else
    err "scanner.py no arranca con uv."
    STATUS=1
    add_note "scanner.py no arranca"
  fi
}

check_required_tools
check_optional_tools

if [[ "$MODE" != "bootstrap" ]]; then
  check_integrity
  audit_permissions
fi

if [[ "$MODE" == "smoke" ]]; then
  run_smoke
fi

[[ "$INTEGRITY" == "1" ]] && STATUS=2

if [[ "$JSON" == "1" ]]; then
  printf '{"status":%d,"mode":"%s","tools":[' "$STATUS" "$MODE"
  first=1
  for item in "${JSON_TOOLS[@]}"; do
    [[ "$first" == "1" ]] || printf ','
    printf '%s' "$item"
    first=0
  done
  printf '],"files":['
  first=1
  for item in "${JSON_FILES[@]}"; do
    [[ "$first" == "1" ]] || printf ','
    printf '%s' "$item"
    first=0
  done
  printf '],"notes":['
  first=1
  for item in "${JSON_NOTES[@]}"; do
    [[ "$first" == "1" ]] || printf ','
    printf '"%s"' "$item"
    first=0
  done
  printf ']}\n'
else
  print_commands
  hr
  case "$STATUS" in
    0) info "${C_GREEN}Todo listo.${C_RESET}" ;;
    1) info "${C_RED}Faltan herramientas o archivos obligatorios.${C_RESET}" ;;
    2) info "${C_RED}Hay un problema de integridad o de permisos.${C_RESET}" ;;
  esac
fi

exit "$STATUS"
