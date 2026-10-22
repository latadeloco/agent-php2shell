#!/usr/bin/env bash
# Wrapper de escaneo php2shell con bloqueo de seguridad y --dry-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

DRY_RUN=0
AUTHORIZED=0
NO_PREFLIGHT=0
ARGS=()

usage() {
  cat <<EOF
Uso: $(basename "$0") [--dry-run] --i-have-permission -u <URL> [opciones del scanner]

  --dry-run             Muestra el comando exacto sin enviar tráfico.
  --i-have-permission   Obligatorio para ejecutar de verdad. Confirma que tienes
                        autorización para probar el objetivo.
  --no-preflight        Salta la revisión previa (solo para pruebas).
  -h, --help            Esta ayuda.

Sin --i-have-permission el wrapper no escanea. El escaneo activo envía hasta
unos 29 MB y puede tumbar PHP-FPM unos segundos.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --i-have-permission) AUTHORIZED=1 ;;
    --no-preflight) NO_PREFLIGHT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

if [[ "${PHP2SHELL_AUTHORIZED:-0}" == "1" ]]; then
  AUTHORIZED=1
fi

if [[ "$DRY_RUN" == "0" && "$AUTHORIZED" == "0" ]]; then
  err "Falta --i-have-permission."
  err "Solo debes escanear servidores que sean tuyos o para los que tengas autorización."
  exit 3
fi

if [[ ! -f "$SCANNER_DIR/scanner.py" ]]; then
  die "No encuentro el scanner en $SCANNER_DIR. Ejecuta el instalador."
fi

URL=""
OUTPUT_SET=0
i=0
while [[ $i -lt ${#ARGS[@]} ]]; do
  case "${ARGS[$i]}" in
    -u|--url)
      URL="${ARGS[$((i + 1))]:-}"
      i=$((i + 2))
      continue
      ;;
    --url=*)
      URL="${ARGS[$i]#--url=}"
      ;;
    -o|--output)
      OUTPUT_SET=1
      i=$((i + 2))
      continue
      ;;
    --output=*)
      OUTPUT_SET=1
      ;;
  esac
  i=$((i + 1))
done

if [[ -z "$URL" ]]; then
  die "Falta -u/--url. Ejemplo: $(basename "$0") --i-have-permission -u https://example.com"
fi

CMD=(uv run --quiet "$SCANNER_DIR/scanner.py" "${ARGS[@]}")

if [[ "$OUTPUT_SET" == "0" ]]; then
  HOST="$(printf '%s' "$URL" \
    | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://##; s#^.*@##; s#[/:?#].*$##; s#[^A-Za-z0-9._-]#_#g')"
  [[ -n "$HOST" ]] || HOST="objetivo"
  OUT_FILE="$STATE_DIR/${HOST}-$(date -u +%Y%m%dT%H%M%SZ).json"
  CMD+=(-o "$OUT_FILE")
fi

if [[ "$NO_PREFLIGHT" == "0" ]]; then
  if ! "$TOOLS_DIR/preflight.sh" --check --quiet >/dev/null; then
    die "La revisión previa ha fallado. Corrige los avisos antes de escanear."
  fi
fi

if [[ "$DRY_RUN" == "1" ]]; then
  info "Comando que se ejecutaría:"
  printf '  '
  printf '%q ' "${CMD[@]}"
  printf '\n'
  exit 0
fi

mkdir -p "$STATE_DIR"
exec "${CMD[@]}"
