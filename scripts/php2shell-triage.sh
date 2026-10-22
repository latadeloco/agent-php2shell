#!/usr/bin/env bash
# Wrapper del triaje de solo lectura de php2shell.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

DRY_RUN=0
SUMMARY=0
TARGET=""

usage() {
  cat <<EOF
Uso: $(basename "$0") [--dry-run] [--summary] [ruta_del_proyecto]

  --dry-run   Muestra el comando exacto sin ejecutar el triaje.
  --summary   Guarda el registro completo y muestra solo el veredicto.
  -h, --help  Esta ayuda.

Si no indicas ruta, se usa el directorio actual.
El triaje es de solo lectura: no cambia nada en el sistema. Guarda un informe
.txt en $STATE_DIR.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --summary) SUMMARY=1 ;;
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
  if [[ -f "$TOOLS_DIR/php2shell-session-audit.sh" ]]; then
    info "Después: auditoría de sesión de solo lectura."
  fi
  exit 0
fi

mkdir -p "$STATE_DIR"
info "Guardando informe de triaje en: $OUT_FILE"
VENDOR_TMP="$(mktemp "${TMPDIR:-/tmp}/php2shell-triage.XXXXXX")"
FULL_TMP="$(mktemp "${TMPDIR:-/tmp}/php2shell-triage-full.XXXXXX")"
set +e
bash "$TRIAGE_SCRIPT" "$TARGET" > "$VENDOR_TMP" 2>&1
CODE=$?
set -e
cat "$VENDOR_TMP" > "$FULL_TMP"

AUDIT_SCRIPT="$TOOLS_DIR/php2shell-session-audit.sh"
if [[ -f "$AUDIT_SCRIPT" ]]; then
  AUDIT_TMP="$(mktemp "${TMPDIR:-/tmp}/php2shell-session-audit.XXXXXX")"
  if bash "$AUDIT_SCRIPT" "$TARGET" > "$AUDIT_TMP" 2>&1; then
    { printf '\n'; cat "$AUDIT_TMP"; } >> "$FULL_TMP"
  else
    printf '\n  [info] auditoría de sesión no disponible\n' >> "$FULL_TMP"
  fi
  rm -f "$AUDIT_TMP"
fi
cp "$FULL_TMP" "$OUT_FILE"

if [[ "$SUMMARY" == "1" ]]; then
  info "Informe completo: $OUT_FILE"
  FLAGS="$(grep -E '^ *\[FLAG\]' "$FULL_TMP" || true)"
  if [[ -n "$FLAGS" ]]; then
    printf '%s\n' "$FLAGS"
  fi
  if grep -q '^== Verdict ==' "$VENDOR_TMP"; then
    sed -n '/^== Verdict ==/,$p' "$VENDOR_TMP"
  else
    tail -n 12 "$VENDOR_TMP"
  fi
else
  cat "$FULL_TMP"
fi

rm -f "$VENDOR_TMP" "$FULL_TMP"
exit "$CODE"
