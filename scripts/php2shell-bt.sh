#!/usr/bin/env bash
# Wrapper del módulo avanzado php2shellbt (cadena de sesión y LFI).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

TARGET=""
CHECKS="warn"
CHECKS_SET=0
ADVANCED=0
AUTHORIZED=0
DRY_RUN=0
NO_PREFLIGHT=0
LFI=""
SESSION_PATH="/tmp/sessions/sess_"
WRITE_PATH=""
READ_PATH=""
TIMEOUT=10
PROBE_TIMEOUT=60
SAPI="auto"
INSECURE=0
FOLLOW_REDIRECTS=0

usage() {
  cat <<EOF
Uso: $(basename "$0") [--dry-run] --i-have-permission -u <URL> [opciones]

  -u, --url URL            Objetivo único.
  --checks LISTA           warn (por defecto), warn,handler,lfi, etc.
  --advanced               Activa warn + handler + lfi según las rutas dadas.
  --lfi PATH               Ruta LFI, por ejemplo "/vuln.php?page=".
  --session-path PATH      Prefijo del fichero de sesión (por defecto: /tmp/sessions/sess_).
  --write-path PATH        Endpoint con serialize_handler=php_serialize.
  --read-path PATH         Endpoint con serialize_handler=php.
  --timeout N              Timeout de peticiones ligeras (10).
  --probe-timeout N        Timeout de crash-probes (60).
  --sapi auto|mod_php|fpm  Reglas de crash (auto).
  --insecure               Desactiva la verificación TLS (no recomendado).
  --follow-redirects       Permite redirecciones (desactivado por defecto).
  --i-have-permission      Obligatorio para ejecutar de verdad.
  --dry-run                Muestra el comando sin ejecutar.
  --no-preflight           Salta la revisión previa (solo pruebas).
  -h, --help               Esta ayuda.

Sin --i-have-permission no se envía tráfico. El check 4 escribe un fichero de
sesión y prueba un LFI; úsalo solo en entornos autorizados.
EOF
}

die_usage() {
  err "$*"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de -u/--url"
      TARGET="$2"
      shift 2
      ;;
    --checks)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --checks"
      CHECKS="$2"
      CHECKS_SET=1
      shift 2
      ;;
    --advanced) ADVANCED=1; shift ;;
    --lfi)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --lfi"
      LFI="$2"
      shift 2
      ;;
    --session-path)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --session-path"
      SESSION_PATH="$2"
      shift 2
      ;;
    --write-path)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --write-path"
      WRITE_PATH="$2"
      shift 2
      ;;
    --read-path)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --read-path"
      READ_PATH="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --timeout"
      TIMEOUT="$2"
      shift 2
      ;;
    --probe-timeout)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --probe-timeout"
      PROBE_TIMEOUT="$2"
      shift 2
      ;;
    --sapi)
      [[ $# -ge 2 ]] || die_usage "Falta el valor de --sapi"
      SAPI="$2"
      shift 2
      ;;
    --insecure) INSECURE=1; shift ;;
    --follow-redirects) FOLLOW_REDIRECTS=1; shift ;;
    --i-have-permission) AUTHORIZED=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-preflight) NO_PREFLIGHT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --targets|--lfi-list|--session-paths-list|--handler-pairs)
      die_usage "Este wrapper no admite listas. Un solo objetivo por ejecución."
      ;;
    *) die_usage "Opción desconocida: $1" ;;
  esac
done

if [[ "${PHP2SHELL_AUTHORIZED:-0}" == "1" ]]; then
  AUTHORIZED=1
fi

if [[ "$DRY_RUN" == "0" && "$AUTHORIZED" == "0" ]]; then
  err "Falta --i-have-permission."
  err "Solo debes usar este módulo en servidores propios o con autorización."
  exit 3
fi

[[ -n "$TARGET" ]] || die_usage "Falta -u/--url."

if [[ "$ADVANCED" == "1" && "$CHECKS_SET" == "0" ]]; then
  if [[ -n "$LFI" && -n "$WRITE_PATH" && -n "$READ_PATH" ]]; then
    CHECKS="warn,handler,lfi"
  elif [[ -n "$LFI" ]]; then
    CHECKS="warn,lfi"
  elif [[ -n "$WRITE_PATH" && -n "$READ_PATH" ]]; then
    CHECKS="warn,handler"
  else
    die_usage "--advanced necesita --lfi y/o --write-path + --read-path."
  fi
fi

IFS=',' read -ra CHECK_LIST <<< "$CHECKS"
for c in "${CHECK_LIST[@]}"; do
  case "$c" in
    fingerprint|crash|warn|handler|lfi) ;;
    *) die_usage "Check no válido: $c" ;;
  esac
done
case ",$CHECKS," in
  *,handler,*) [[ -n "$WRITE_PATH" && -n "$READ_PATH" ]] || die_usage "handler requiere --write-path y --read-path." ;;
esac
case ",$CHECKS," in
  *,lfi,*) [[ -n "$LFI" ]] || die_usage "lfi requiere --lfi." ;;
esac

if [[ ! -f "$VENDOR_DIR/php2shellbt.py" ]]; then
  die "No encuentro php2shellbt.py en $VENDOR_DIR. Ejecuta el instalador."
fi

if [[ "$NO_PREFLIGHT" == "0" ]]; then
  if ! "$TOOLS_DIR/preflight.sh" --check --quiet >/dev/null; then
    die "La revisión previa ha fallado. Corrige los avisos antes de continuar."
  fi
fi

if have_cmd python3; then
  PY=(python3)
elif have_cmd uv; then
  PY=(uv run --quiet python)
else
  die "Falta python3 o uv para ejecutar php2shellbt."
fi

HOST="$(printf '%s' "$TARGET" \
  | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://##; s#^.*@##; s#[/:?#].*$##; s#[^A-Za-z0-9._-]#_#g')"
[[ -n "$HOST" ]] || HOST="objetivo"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_JSON="$STATE_DIR/${HOST}-bt-${STAMP}.json"
OUT_LOG="$STATE_DIR/${HOST}-bt-${STAMP}.log"

CMD=("${PY[@]}" "$VENDOR_DIR/php2shellbt.py" "$TARGET" --checks "$CHECKS" --json --no-color)
CMD+=(--timeout "$TIMEOUT" --probe-timeout "$PROBE_TIMEOUT" --sapi "$SAPI")
if [[ -n "$LFI" ]]; then CMD+=(--lfi "$LFI"); fi
if [[ -n "$SESSION_PATH" ]]; then CMD+=(--session-path "$SESSION_PATH"); fi
if [[ -n "$WRITE_PATH" ]]; then CMD+=(--write-path "$WRITE_PATH"); fi
if [[ -n "$READ_PATH" ]]; then CMD+=(--read-path "$READ_PATH"); fi
if [[ "$INSECURE" == "1" ]]; then CMD+=(--insecure); fi
if [[ "$FOLLOW_REDIRECTS" == "1" ]]; then CMD+=(--follow-redirects); fi

if [[ "$DRY_RUN" == "1" ]]; then
  info "Comando que se ejecutaría:"
  printf '  '
  printf '%q ' "${CMD[@]}"
  printf '\n'
  info "Informe: $OUT_JSON"
  exit 0
fi

mkdir -p "$STATE_DIR"
info "Ejecutando módulo avanzado (checks: $CHECKS)..."
set +e
"${CMD[@]}" > "$OUT_JSON" 2> "$OUT_LOG"
CODE=$?
set -e

if [[ ! -s "$OUT_JSON" ]]; then
  err "php2shellbt no devolvió JSON. Revisa el log: $OUT_LOG"
  exit 2
fi

SUMMARY="$("${PY[@]}" - "$OUT_JSON" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception as exc:
    print(f"No se pudo leer el JSON: {exc}")
    sys.exit(0)
labels = {
    "cve109619": "Versión PHP",
    "cve109618_crash": "Crash-probe",
    "cve109618_warn": "Avisos de sesión",
    "handler": "Handler mismatch",
    "session_lfi": "Sesión + LFI",
}
for key, label in labels.items():
    if key in data.get("results", {}):
        print(f"- {label}: {data['results'][key]}")
PY
)"

info "$SUMMARY"
info "Informe: $OUT_JSON"
info "Log:     $OUT_LOG"
exit "$CODE"
