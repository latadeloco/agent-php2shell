#!/usr/bin/env bash
# Auditoría de sesión de solo lectura para php2shell.
# Busca señales de las cadenas de sesión (A/C/E) sin modificar nada.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

SUMMARY=0
TARGET="."
SESSIONS_DIRS=()
LOG_DIRS=()

usage() {
  cat <<EOF
Uso: $(basename "$0") [--summary] [--sessions-dir DIR] [--log-dir DIR] [ruta]

  --summary            Muestra solo los FLAG y el recuento.
  --sessions-dir DIR   Directorio de sesiones a revisar (se puede repetir).
  --log-dir DIR        Directorio de logs a revisar (se puede repetir).
  -h, --help           Esta ayuda.

Sin opciones intenta detectar el save_path de PHP y los logs habituales.
Es de solo lectura: no borra, no limpia y no cambia nada.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) SUMMARY=1 ;;
    --sessions-dir)
      [[ $# -ge 2 ]] || die "Falta el valor de --sessions-dir."
      SESSIONS_DIRS+=("$2")
      shift
      ;;
    --sessions-dir=*) SESSIONS_DIRS+=("${1#--sessions-dir=}") ;;
    --log-dir)
      [[ $# -ge 2 ]] || die "Falta el valor de --log-dir."
      LOG_DIRS+=("$2")
      shift
      ;;
    --log-dir=*) LOG_DIRS+=("${1#--log-dir=}") ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Opción desconocida: $1" ;;
    *)
      TARGET="$1"
      shift
      break
      ;;
  esac
  shift
done

[[ -d "$TARGET" ]] || die "'$TARGET' no existe o no es un directorio."

FLAGS=0
WARNS=0
FLAG_LINES=()
WARN_LINES=()
flag() {
  FLAG_LINES+=("$*")
  FLAGS=$((FLAGS + 1))
  [[ "$SUMMARY" == "1" ]] || printf '  [FLAG] %s\n' "$*"
}
sa_warn() {
  WARN_LINES+=("$*")
  WARNS=$((WARNS + 1))
  [[ "$SUMMARY" == "1" ]] || printf '  [warn] %s\n' "$*"
}
sa_info() { [[ "$SUMMARY" == "1" ]] || printf '  [info] %s\n' "$*"; }
sa_ok() { [[ "$SUMMARY" == "1" ]] || printf '  [ok] %s\n' "$*"; }

if [[ ${#SESSIONS_DIRS[@]} -eq 0 ]]; then
  if have_cmd php; then
    save_path="$(php -i 2>/dev/null | awk -F'=> ' '/^session.save_path/ {print $2; exit}')"
    if [[ -n "$save_path" && "$save_path" != "no value" ]]; then
      IFS=';' read -r -a _parts <<< "$save_path"
      last="${_parts[${#_parts[@]}-1]}"
      [[ -n "$last" && -d "$last" ]] && SESSIONS_DIRS+=("$last")
    fi
  fi
  for d in /var/lib/php/sessions /var/lib/php/session /tmp/sessions; do
    [[ -d "$d" ]] && SESSIONS_DIRS+=("$d")
  done
fi

if [[ ${#LOG_DIRS[@]} -eq 0 ]]; then
  for d in /var/log /var/log/apache2 /var/log/nginx; do
    [[ -d "$d" ]] && LOG_DIRS+=("$d")
  done
fi

printf 'PHP2Shell auditoría de sesión (solo lectura)\n'
printf 'objetivo: %s\n' "$TARGET"

session_seen=0
if [[ ${#SESSIONS_DIRS[@]} -eq 0 ]]; then
  sa_info "no se ha detectado un directorio de sesiones; pásalo con --sessions-dir"
else
  for dir in "${SESSIONS_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    sa_info "revisando sesiones en $dir"
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      session_seen=$((session_seen + 1))
      if grep -qE '<\?(php|=)' "$file" 2>/dev/null; then
        flag "código PHP dentro de un fichero de sesión: $file"
      elif grep -qE '\|(O|a|C):[0-9]+:' "$file" 2>/dev/null; then
        flag "objeto serializado dentro de un fichero de sesión: $file"
      fi
    done < <(find "$dir" -maxdepth 1 -type f -name 'sess_*' -size -1048576c 2>/dev/null | head -n 500)
  done
  if [[ "$session_seen" -eq 0 ]]; then
    sa_info "no se han encontrado ficheros sess_* legibles"
  elif [[ "$FLAGS" -eq 0 ]]; then
    sa_ok "sin señales en $session_seen fichero(s) de sesión"
  fi
fi

logs_seen=0
if [[ ${#LOG_DIRS[@]} -eq 0 ]]; then
  sa_info "no se ha detectado un directorio de logs; pásalo con --log-dir"
else
  while IFS= read -r log; do
    [[ -n "$log" ]] || continue
    logs_seen=$((logs_seen + 1))
    if grep -qi 'Session object destruction failed' "$log" 2>/dev/null; then
      flag "fallo de destrucción de sesión en $log"
    fi
    if grep -q 'PHP_SESSION_UPLOAD_PROGRESS' "$log" 2>/dev/null; then
      sa_warn "referencia a PHP_SESSION_UPLOAD_PROGRESS en $log"
    fi
  done < <(find "${LOG_DIRS[@]}" -maxdepth 2 -type f \
             \( -name 'modsec_audit.log*' -o -name 'php*-fpm.log*' -o -name 'php_errors.log*' -o -name 'error.log*' \) \
             2>/dev/null | head -n 100)
  if [[ "$logs_seen" -eq 0 ]]; then
    sa_info "no se han encontrado logs de PHP o ModSecurity legibles"
  fi
fi

if [[ "$SUMMARY" == "1" && ${#FLAG_LINES[@]} -gt 0 ]]; then
  for line in "${FLAG_LINES[@]}"; do
    printf '  [FLAG] %s\n' "$line"
  done
fi

printf 'Auditoría de sesión: %d flag(s), %d aviso(s).\n' "$FLAGS" "$WARNS"
if [[ "$FLAGS" -gt 0 ]]; then
  printf 'Hay señales compatibles con un compromiso. Conserva los logs y rota secretos.\n'
elif [[ "$WARNS" -gt 0 ]]; then
  printf 'No hay señales fuertes. Revisa los avisos antes de relajarte.\n'
else
  printf 'No se han visto señales en lo que este script puede leer.\n'
fi
