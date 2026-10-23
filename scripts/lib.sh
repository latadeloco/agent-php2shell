#!/usr/bin/env bash
# Funciones compartidas por el instalador y los wrappers de php2shell-agent.

PHP2SHELL_SCANNER_REPO="${PHP2SHELL_SCANNER_REPO:-https://github.com/assetnote/php2shell-scanner.git}"
PHP2SHELL_SCANNER_COMMIT="${PHP2SHELL_SCANNER_COMMIT:-353545fe9e72ff85921a84cf396d71b3d15e936e}"
PHP2SHELL_TRIAGE_URL="${PHP2SHELL_TRIAGE_URL:-https://gist.githubusercontent.com/Sairahcaz/2c22b4a68fd5b75e410c7f9f69f485a0/raw/ec40176f383156c29a8fa3f60d4a88c82cb683a8/php2shell-triage.sh}"
PHP2SHELL_TRIAGE_REV="${PHP2SHELL_TRIAGE_REV:-ec40176f383156c29a8fa3f60d4a88c82cb683a8}"
PHP2SHELL_TRIAGE_SHA256="${PHP2SHELL_TRIAGE_SHA256:-355a12feb009bc9a2071155c56eec38a67b0c3b9bfdc30014e36a198418b672d}"
PHP2SHELL_BT_COMMIT="${PHP2SHELL_BT_COMMIT:-621f557297f69a26ee7e28d21bc042b736725a63}"
PHP2SHELL_BT_SHA256="${PHP2SHELL_BT_SHA256:-0aec1b8df8959b8bc97a6bc333aa21644c5e9f9492dba49cf93fc4853b494398}"

PHP2SHELL_RULES_COMMIT="${PHP2SHELL_RULES_COMMIT:-93df49253e79774e61833938c40aff3b79c6bde1}"
PHP2SHELL_RULES_RAW_BASE="${PHP2SHELL_RULES_RAW_BASE:-https://raw.githubusercontent.com/GoldraK/php2shell-poc/${PHP2SHELL_RULES_COMMIT}/detection}"
PHP2SHELL_RULES_FILES="${PHP2SHELL_RULES_FILES:-modsecurity.conf php2shell.lua php2shell.rules php2shell.yaml}"
PHP2SHELL_RULES_SHA256_MODSECURITY="${PHP2SHELL_RULES_SHA256_MODSECURITY:-4454ce0a50455564b74c02f836de1956af11daec53a2b288a030e545359e5fe6}"
PHP2SHELL_RULES_SHA256_LUA="${PHP2SHELL_RULES_SHA256_LUA:-31c42602d7128b32d27169b3a573a5e660bf4ac0bd35d6b97df245aca0f07758}"
PHP2SHELL_RULES_SHA256_RULES="${PHP2SHELL_RULES_SHA256_RULES:-61c4741c7a8dd4ee8e383d868c5ed4ee8f108fccb008e6e8b9434f62a4254bd8}"
PHP2SHELL_RULES_SHA256_YAML="${PHP2SHELL_RULES_SHA256_YAML:-bd7197ad4ed4293c119a6968941b5239d14a73ab6d141dd498aa6d749de860b8}"

php2shell_rules_hash_for() {
  case "$1" in
    modsecurity.conf) printf '%s' "$PHP2SHELL_RULES_SHA256_MODSECURITY" ;;
    php2shell.lua) printf '%s' "$PHP2SHELL_RULES_SHA256_LUA" ;;
    php2shell.rules) printf '%s' "$PHP2SHELL_RULES_SHA256_RULES" ;;
    php2shell.yaml) printf '%s' "$PHP2SHELL_RULES_SHA256_YAML" ;;
    *) return 1 ;;
  esac
}

if command -v sha256sum >/dev/null 2>&1; then
  HASH_TOOL=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  HASH_TOOL=(shasum -a 256)
else
  HASH_TOOL=()
fi

php2shell_init_paths() {
  DATA_DIR="${PHP2SHELL_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/php2shell-agent}"
  STATE_DIR="${PHP2SHELL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/php2shell-scans}"
  TOOLS_DIR="$DATA_DIR/tools"
  SCANNER_DIR="$DATA_DIR/scanner"
  VENDOR_DIR="$TOOLS_DIR/vendor"
  RULES_DIR="$DATA_DIR/vendor/rules"
  CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
  export DATA_DIR STATE_DIR TOOLS_DIR SCANNER_DIR VENDOR_DIR RULES_DIR CONFIG_DIR
}

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_BOLD=""
  C_RESET=""
fi

info() { printf '%s\n' "$*"; }
ok() { [[ "${BRIEF:-0}" == "1" ]] && return 0; printf ' %s[ok]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf ' %s[aviso]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err() { printf ' %s[error]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
hr() { printf '%s\n' "------------------------------------------------------------"; }

die() {
  err "$*"
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  have_cmd "$1" || die "Falta la herramienta obligatoria '$1'."
}

sha256_of() {
  if [[ ${#HASH_TOOL[@]} -eq 0 ]]; then
    return 2
  fi
  "${HASH_TOOL[@]}" "$1" | awk '{print $1}'
}

confirm() {
  local prompt="${1:-¿Continuar? [s/N] }"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "No hay terminal interactiva para confirmar. Usa --yes."
  fi
  local answer
  read -r -p "$prompt" answer
  [[ "$answer" =~ ^[sSyY]$ ]]
}

backup_file() {
  local file="$1"
  [[ -e "$file" ]] || return 0
  local backup
  backup="${file}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  cp -a "$file" "$backup"
  info "Backup creado: $backup"
}

render_template() {
  local src="$1"
  local dst="$2"
  local model_line="${MODEL_LINE:-}"
  local model_toml_line="${MODEL_TOML_LINE:-}"
  awk \
    -v data="$DATA_DIR" \
    -v tools="$TOOLS_DIR" \
    -v scanner="$SCANNER_DIR" \
    -v state="$STATE_DIR" \
    -v vendor="$VENDOR_DIR" \
    -v model="$model_line" \
    -v model_toml="$model_toml_line" '
    function repl(s, from, to,    out, i) {
      out = ""
      while ((i = index(s, from)) > 0) {
        out = out substr(s, 1, i - 1) to
        s = substr(s, i + length(from))
      }
      return out s
    }
    {
      $0 = repl($0, "@@DATA_DIR@@", data)
      $0 = repl($0, "@@TOOLS_DIR@@", tools)
      $0 = repl($0, "@@SCANNER_DIR@@", scanner)
      $0 = repl($0, "@@STATE_DIR@@", state)
      $0 = repl($0, "@@VENDOR_DIR@@", vendor)
      $0 = repl($0, "@@MODEL_LINE@@", model)
      $0 = repl($0, "@@MODEL_TOML_LINE@@", model_toml)
      print
    }
  ' "$src" > "$dst"
}

render_adapter() {
  local core="$1"
  local adapter="$2"
  local dst="$3"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/php2shell-render.XXXXXX")"
  awk -v core_file="$core" '
    /@@CORE@@/ {
      while ((getline line < core_file) > 0) print line
      close(core_file)
      next
    }
    { print }
  ' "$adapter" > "$tmp"
  render_template "$tmp" "$dst"
  rm -f "$tmp"
}

install_marked_block() {
  local file="$1"
  local block_file="$2"
  local begin="$3"
  local end="$4"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/php2shell-block.XXXXXX")"
  if [[ -f "$file" ]]; then
    awk -v b="$begin" -v e="$end" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip { print }
    ' "$file" > "$tmp"
  else
    : > "$tmp"
  fi
  printf '\n%s\n' "$begin" >> "$tmp"
  cat "$block_file" >> "$tmp"
  printf '%s\n' "$end" >> "$tmp"
  mv "$tmp" "$file"
}

remove_marked_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  [[ -f "$file" ]] || return 0
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/php2shell-block.XXXXXX")"
  awk -v b="$begin" -v e="$end" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}
