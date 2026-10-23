#!/usr/bin/env bash
# Auditoría de solo lectura para CVE-2026-115560 (session upload progress).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

SUMMARY=0
TARGET="."

usage() {
  cat <<EOF
Uso: $(basename "$0") [--summary] [ruta_del_proyecto]

  --summary   Muestra solo el veredicto, los hallazgos y el remedio.
  -h, --help  Esta ayuda.

Busca las condiciones de CVE-2026-115560:
  - session.serialize_handler = php_binary|php_serialize
  - ini_set('session.serialize_handler', 'php') antes de session_start()
  - session.upload_progress.enabled activo o no definido

Es de solo lectura: no cambia nada, no envía tráfico y no ejecuta la aplicación.
La configuración efectiva del servidor puede estar fuera del repositorio.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) SUMMARY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Opción desconocida: $1" ;;
    *) TARGET="$1"; shift; break ;;
  esac
done

[[ -d "$TARGET" ]] || die "'$TARGET' no existe o no es un directorio."
TARGET_ABS="$(cd "$TARGET" && pwd)"

CONFIG_FILES=()
PHP_FILES=()
FINDINGS=()
FLAGS=0
WARNS=0

add_finding() {
  local level="$1" file="$2" line="$3" message="$4"
  FINDINGS+=("${level}|${file}|${line}|${message}")
}

flag() {
  FLAGS=$((FLAGS + 1))
  add_finding FLAG "$@"
}

warn() {
  WARNS=$((WARNS + 1))
  add_finding WARN "$@"
}

collect_files() {
  local f
  while IFS= read -r -d '' f; do
    CONFIG_FILES+=("$f")
  done < <(find "$TARGET_ABS" \
    \( -name '.git' -o -name 'vendor' -o -name 'node_modules' \
       -o -name 'storage' -o -name '.cache' \) -prune -o \
    -type f \( -name 'php.ini' -o -name '.user.ini' -o -name '*.ini' \
       -o -name '*.conf' -o -name '.htaccess' -o -name 'Dockerfile*' \
       -o -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \
       -o -name 'compose*.yml' -o -name 'compose*.yaml' \) -print0 2>/dev/null)

  while IFS= read -r -d '' f; do
    PHP_FILES+=("$f")
  done < <(find "$TARGET_ABS" \
    \( -name '.git' -o -name 'vendor' -o -name 'node_modules' \
       -o -name 'storage' -o -name '.cache' \) -prune -o \
    -type f \( -name '*.php' -o -name '*.phtml' -o -name '*.inc' \) -print0 2>/dev/null)
}

BASE_RISKY=0
BASE_PHP=0
BASE_FILE=""
UPLOAD_STATE="unknown"
UPLOAD_FILE=""

parse_config_files() {
  local f text line text_lc val
  for f in "${CONFIG_FILES[@]+"${CONFIG_FILES[@]}"}"; do
    while IFS= read -r entry; do
      line="${entry%%:*}"
      text="${entry#*:}"
      text_lc="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
      if [[ "$text_lc" =~ session\.serialize_handler[^a-z_]*(php_binary|php_serialize|php)([^a-z_]|$) ]]; then
        val="${BASH_REMATCH[1]}"
        case "$val" in
          php_binary|php_serialize)
            BASE_RISKY=1
            BASE_FILE="${f}:${line}"
            ;;
          php)
            BASE_PHP=1
            [[ -n "$BASE_FILE" ]] || BASE_FILE="${f}:${line}"
            ;;
        esac
      fi
      if [[ "$text_lc" =~ session\.upload_progress\.enabled[^a-z0-9]*(on|off|1|0|true|false|yes|no) ]]; then
        val="${BASH_REMATCH[1]}"
        case "$val" in
          on|1|true|yes)
            if [[ "$UPLOAD_STATE" == "disabled" ]]; then
              UPLOAD_STATE="conflict"
            else
              UPLOAD_STATE="enabled"
            fi
            UPLOAD_FILE="${f}:${line}"
            ;;
          off|0|false|no)
            if [[ "$UPLOAD_STATE" == "enabled" ]]; then
              UPLOAD_STATE="conflict"
            else
              UPLOAD_STATE="disabled"
            fi
            UPLOAD_FILE="${f}:${line}"
            ;;
        esac
      fi
    done < <(grep -nE 'session\.(serialize_handler|upload_progress\.enabled)' "$f" 2>/dev/null || true)
  done
}

RUNTIME_BEFORE=0
RUNTIME_AFTER=0
RUNTIME_UNKNOWN=0
RUNTIME_FILE=""
RUNTIME_LINE=""
START_LINE=""

parse_php_files() {
  local f entry line text ini_lines start_lines ini_line start_line
  for f in "${PHP_FILES[@]+"${PHP_FILES[@]}"}"; do
    ini_lines="$(grep -nE "ini_set[[:space:]]*\([[:space:]]*['\"]session\\.serialize_handler['\"][[:space:]]*,[[:space:]]*['\"]php['\"]" "$f" 2>/dev/null || true)"
    [[ -n "$ini_lines" ]] || continue
    start_lines="$(grep -nE 'session_start[[:space:]]*\(' "$f" 2>/dev/null || true)"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      ini_line="${entry%%:*}"
      if [[ -z "$start_lines" ]]; then
        RUNTIME_UNKNOWN=1
        RUNTIME_FILE="$f"
        RUNTIME_LINE="$ini_line"
        continue
      fi
      while IFS= read -r start_entry; do
        [[ -n "$start_entry" ]] || continue
        start_line="${start_entry%%:*}"
        if (( ini_line < start_line )); then
          RUNTIME_BEFORE=1
          RUNTIME_FILE="$f"
          RUNTIME_LINE="$ini_line"
          START_LINE="$start_line"
        else
          RUNTIME_AFTER=1
        fi
      done <<< "$start_lines"
    done <<< "$ini_lines"
  done
}

collect_files
parse_config_files
parse_php_files

if [[ "$UPLOAD_STATE" == "conflict" ]]; then
  warn "${UPLOAD_FILE:-$TARGET_ABS}" "-" "session.upload_progress.enabled tiene valores contradictorios en el repositorio"
fi

if [[ "$BASE_RISKY" == "1" ]]; then
  add_finding INFO "$BASE_FILE" "-" "session.serialize_handler configurado como php_binary/php_serialize"
fi
if [[ "$BASE_PHP" == "1" && "$BASE_RISKY" == "0" ]]; then
  add_finding INFO "$BASE_FILE" "-" "session.serialize_handler configurado como php"
fi
if [[ "$RUNTIME_BEFORE" == "1" ]]; then
  flag "$RUNTIME_FILE" "$RUNTIME_LINE" "ini_set('session.serialize_handler','php') antes de session_start() (línea $START_LINE)"
elif [[ "$RUNTIME_AFTER" == "1" ]]; then
  warn "$RUNTIME_FILE" "$RUNTIME_LINE" "cambio a 'php' después de session_start(); no coincide con el patrón del CVE"
elif [[ "$RUNTIME_UNKNOWN" == "1" ]]; then
  warn "$RUNTIME_FILE" "$RUNTIME_LINE" "ini_set('session.serialize_handler','php') encontrado, pero no se ve session_start() en el mismo archivo"
fi

VERDICT="UNKNOWN"

if [[ "$BASE_RISKY" == "1" && "$RUNTIME_BEFORE" == "1" ]]; then
  case "$UPLOAD_STATE" in
    disabled)
      warn "${UPLOAD_FILE:-$TARGET_ABS}" "-" "upload_progress está desactivado en el repositorio; confirma la configuración efectiva del servidor"
      VERDICT="WARN"
      ;;
    enabled)
      flag "${UPLOAD_FILE:-$TARGET_ABS}" "-" "upload_progress está activo"
      VERDICT="FLAG"
      ;;
    conflict)
      flag "${UPLOAD_FILE:-$TARGET_ABS}" "-" "upload_progress tiene valores contradictorios"
      VERDICT="FLAG"
      ;;
    *)
      flag "${UPLOAD_FILE:-$TARGET_ABS}" "-" "upload_progress no está definido; por defecto On"
      VERDICT="FLAG"
      ;;
  esac
elif [[ "$BASE_RISKY" == "1" && "$RUNTIME_UNKNOWN" == "1" ]]; then
  VERDICT="WARN"
elif [[ "$BASE_RISKY" == "1" ]]; then
  warn "${BASE_FILE:-$TARGET_ABS}" "-" "serialize_handler de riesgo, pero no se ha visto el cambio a 'php' antes de session_start()"
  VERDICT="WARN"
elif [[ "$RUNTIME_BEFORE" == "1" && "$BASE_RISKY" == "0" ]]; then
  if [[ "$BASE_PHP" == "1" ]]; then
    VERDICT="OK"
  else
    warn "$RUNTIME_FILE" "$RUNTIME_LINE" "cambio a 'php' sin evidencia de serialize_handler base php_binary/php_serialize"
    VERDICT="WARN"
  fi
elif [[ "$BASE_PHP" == "1" && "$RUNTIME_BEFORE" == "0" && "$RUNTIME_AFTER" == "0" && "$RUNTIME_UNKNOWN" == "0" ]]; then
  VERDICT="OK"
elif [[ "$BASE_PHP" == "1" ]]; then
  VERDICT="WARN"
fi

print_findings() {
  local item level file line message
  local printed=0
  for item in "${FINDINGS[@]+"${FINDINGS[@]}"}"; do
    level="${item%%|*}"
    item="${item#*|}"
    file="${item%%|*}"
    item="${item#*|}"
    line="${item%%|*}"
    message="${item#*|}"
    if [[ "$SUMMARY" == "1" && "$level" == "INFO" ]]; then
      continue
    fi
    if [[ "$line" == "-" ]]; then
      printf '  [%s] %s: %s\n' "$level" "$file" "$message"
    else
      printf '  [%s] %s:%s: %s\n' "$level" "$file" "$line" "$message"
    fi
    printed=$((printed + 1))
    if (( printed >= 12 )); then
      printf '  ... (%d hallazgo(s) más)\n' "$((${#FINDINGS[@]} - printed))"
      break
    fi
  done
}

if [[ "$SUMMARY" == "1" ]]; then
  info "Veredicto: $VERDICT"
  print_findings
else
  hr
  info "${C_BOLD}Auditoría de configuración CVE-2026-115560${C_RESET}"
  hr
  info "Proyecto: $TARGET_ABS"
  info "Veredicto: $VERDICT"
  print_findings
fi

case "$VERDICT" in
  FLAG)
    info "Remedio: session.upload_progress.enabled=0 en la config efectiva del servidor,"
    info "unificar session.serialize_handler y revisar el orden de session_start()."
    ;;
  WARN|UNKNOWN)
    info "No hay confirmación completa. Revisa la configuración efectiva del servidor."
    ;;
  OK)
    info "No se ha encontrado la combinación de CVE-2026-115560 en los archivos revisados."
    ;;
esac

if [[ "$SUMMARY" != "1" ]]; then
  info ""
  info "Límites: solo revisa archivos del proyecto. La configuración efectiva puede estar"
  info "en el hosting, variables de entorno o en un php.ini fuera del repositorio."
fi

if [[ "$VERDICT" == "FLAG" ]]; then
  exit 2
fi
exit 0
