#!/usr/bin/env bash
# Wrapper del triaje de solo lectura de php2shell.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

DRY_RUN=0
TARGET=""

usage() {
  cat <<EOF
Uso: $(basename "$0") [--dry-run] [ruta_del_proyecto]

  --dry-run   Muestra el comando exacto sin ejecutar el triaje.
  -h, --help  Esta ayuda.

Si no indicas ruta, se usa el directorio actual.
El triaje es de solo lectura: no cambia nada en el sistema. Guarda un informe
.txt en $STATE_DIR.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      die "Opción desconocida: $1"
      ;;
    *)
      TARGET="$1"
      shift
      break
      ;;
  esac
  shift
done

[[ -n "$TARGET" ]] || TARGET="."

if [[ ! -d "$TARGET" ]]; then
  die "'$TARGET' no existe o no es un directorio."
fi

TRIAGE_SCRIPT="$VENDOR_DIR/php2shell-triage.sh"
if [[ ! -f "$TRIAGE_SCRIPT" ]]; then
  die "No encuentro el script de triaje en $TRIAGE_SCRIPT. Ejecuta el instalador."
fi

ACTUAL_HASH="$(sha256_of "$TRIAGE_SCRIPT")"
if [[ "$ACTUAL_HASH" != "$PHP2SHELL_TRIAGE_SHA256" ]]; then
  die "El script de triaje no coincide con el hash fijado. Reinstala para verificarlo."
fi

TARGET_ABS="$(cd "$TARGET" && pwd)"
NAME="$(basename "$TARGET_ABS")"
OUT_FILE="$STATE_DIR/${NAME}-triage-$(date -u +%Y%m%dT%H%M%SZ).txt"
CMD=(bash "$TRIAGE_SCRIPT" "$TARGET")

if [[ "$DRY_RUN" == "1" ]]; then
  info "Comando que se ejecutaría:"
  printf '  '
  printf '%q ' "${CMD[@]}"
  printf '\n'
  info "Informe: $OUT_FILE"
  exit 0
fi

mkdir -p "$STATE_DIR"
info "Guardando informe de triaje en: $OUT_FILE"
bash "$TRIAGE_SCRIPT" "$TARGET" 2>&1 | tee "$OUT_FILE"
exit "${PIPESTATUS[0]}"
