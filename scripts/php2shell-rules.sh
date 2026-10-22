#!/usr/bin/env bash
# Descarga y verifica las reglas de defensa de php2shell.
# Por defecto no escribe nada: exige --install. Nunca toca rutas del sistema.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
php2shell_init_paths

DRY_RUN=0
INSTALL=0
PROFILE="alert"
AGGRESSIVE=0
DEST="$RULES_DIR"

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

  --dry-run             Muestra el plan sin descargar ni escribir (por defecto).
  --install             Descarga, verifica e instala las reglas en --dest.
  --profile alert|block Perfil de las reglas ModSecurity (por defecto: alert).
  --include-aggressive  Incluye la regla de multipart chunked (más falsos positivos).
  --dest DIR            Destino (por defecto: $RULES_DIR).
  -h, --help            Esta ayuda.

Perfil "alert": las reglas ModSecurity registran pero no bloquean.
Perfil "block": las reglas ModSecurity bloquean. Úsalo solo si entiendes el riesgo.
Nunca escribe en /etc ni usa sudo: solo en el destino indicado.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --install) INSTALL=1 ;;
    --profile)
      [[ $# -ge 2 ]] || die "Falta el valor de --profile."
      PROFILE="$2"
      shift
      ;;
    --profile=*) PROFILE="${1#--profile=}" ;;
    --include-aggressive) AGGRESSIVE=1 ;;
    --dest)
      [[ $# -ge 2 ]] || die "Falta el valor de --dest."
      DEST="$2"
      shift
      ;;
    --dest=*) DEST="${1#--dest=}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
  shift
done

case "$PROFILE" in
  alert|block) ;;
  *) die "Perfil no válido: $PROFILE. Usa 'alert' o 'block'." ;;
esac

require_cmd curl
if [[ ${#HASH_TOOL[@]} -eq 0 ]]; then
  die "Falta sha256sum o shasum para verificar las reglas."
fi

info "Fuente: GoldraK/php2shell-poc (commit $PHP2SHELL_RULES_COMMIT)"
info "Perfil: $PROFILE"
info "Regla agresiva (chunked multipart): $([[ "$AGGRESSIVE" == "1" ]] && echo incluida || echo excluida)"
info "Destino: $DEST"

if [[ "$INSTALL" == "0" ]]; then
  info ""
  info "Modo simulación: no se ha descargado ni escrito nada."
  info "Para instalar: $(basename "$0") --install --profile $PROFILE"
  exit 0
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-rules.XXXXXX")"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

for name in $PHP2SHELL_RULES_FILES; do
  url="$PHP2SHELL_RULES_RAW_BASE/$name"
  dest="$TMP_DIR/$name"
  info "Descargando $name..."
  curl -fsSL --max-time 30 "$url" -o "$dest" || die "No se pudo descargar $name."

  expected="$(php2shell_rules_hash_for "$name")" || die "Sin hash fijado para $name."
  actual="$(sha256_of "$dest")" || die "No se pudo calcular el hash de $name."
  [[ "$actual" == "$expected" ]] \
    || die "El hash de $name no coincide. Esperado: $expected. Obtenido: $actual."
done

if [[ "$PROFILE" == "alert" ]]; then
  grep -Ev '^[[:space:]]*status:[0-9]+,[[:space:]]*\\?[[:space:]]*$' "$TMP_DIR/modsecurity.conf" \
    | sed 's/deny/pass/g' > "$TMP_DIR/modsecurity.alert.conf"
  mv "$TMP_DIR/modsecurity.alert.conf" "$TMP_DIR/modsecurity.conf"
fi

if [[ "$AGGRESSIVE" == "0" ]]; then
  awk '
    /^# SID 2026105/ { skip = 1 }
    skip && /^\)$/ { skip = 0; next }
    skip { next }
    /^alert / { inrule = 1; buf = $0 "\n"; next }
    inrule {
      buf = buf $0 "\n"
      if ($0 == ")") {
        if (buf !~ /sid:2026105;/) printf "%s", buf
        inrule = 0
        buf = ""
      }
      next
    }
    { print }
  ' "$TMP_DIR/php2shell.rules" > "$TMP_DIR/php2shell.rules.tmp"
  mv "$TMP_DIR/php2shell.rules.tmp" "$TMP_DIR/php2shell.rules"

  awk '
    /^# --- Rule 9900106/ { skip = 1; next }
    skip && (/^# --- Rule / || /^# ====/) { skip = 0 }
    !skip { print }
  ' "$TMP_DIR/modsecurity.conf" > "$TMP_DIR/modsecurity.conf.tmp"
  mv "$TMP_DIR/modsecurity.conf.tmp" "$TMP_DIR/modsecurity.conf"
fi

mkdir -p "$DEST" || die "No se pudo crear $DEST."
for name in $PHP2SHELL_RULES_FILES; do
  cp "$TMP_DIR/$name" "$DEST/$name"
done

ok "Reglas instaladas en $DEST (perfil $PROFILE)."
info "No se ha modificado ninguna configuración del sistema."
info "Copia o incluye esos ficheros en tu WAF/IDS/SIEM cuando quieras."
