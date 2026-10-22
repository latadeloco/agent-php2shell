#!/usr/bin/env bash
# Publica el contenido de wiki/ en la wiki de GitHub.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"

WIKI_URL="${WIKI_URL:-git@github.com:latadeloco/agent-php2shell.wiki.git}"
MESSAGE="docs: actualizar wiki"
DRY_RUN=0

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

  --wiki-url URL   URL del repositorio wiki (por defecto: $WIKI_URL)
  --message TEXT   Mensaje del commit
  --dry-run        Muestra qué haría sin publicar
  -h, --help       Esta ayuda

Si la wiki todavía no existe, cree la primera página desde la web:
  https://github.com/latadeloco/agent-php2shell/wiki
Después vuelva a ejecutar este script.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wiki-url)
      [[ $# -ge 2 ]] || die "Falta el valor de --wiki-url"
      WIKI_URL="$2"
      shift 2
      ;;
    --message)
      [[ $# -ge 2 ]] || die "Falta el valor de --message"
      MESSAGE="$2"
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opción desconocida: $1" ;;
  esac
done

[[ -d "$REPO_DIR/wiki" ]] || die "No encuentro el directorio wiki/."

TMP="$(mktemp -d "${TMPDIR:-/tmp}/php2shell-wiki.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

if [[ "$DRY_RUN" == "1" ]]; then
  info "Se copiarían estos archivos a $WIKI_URL:"
  for file in "$REPO_DIR"/wiki/*.md; do
    info "  $(basename "$file")"
  done
  info "Modo --dry-run: no se ha publicado nada."
  exit 0
fi

info "Clonando la wiki..."
if ! git clone --quiet "$WIKI_URL" "$TMP/wiki" 2>/dev/null; then
  err "No se pudo clonar la wiki."
  info "GitHub no crea el repositorio de la wiki hasta que existe la primera página."
  info "Abra https://github.com/latadeloco/agent-php2shell/wiki"
  info "Cree una página llamada 'Home' (puede ser un texto breve) y guarde."
  info "Después vuelva a ejecutar:"
  info "  ./scripts/publish-wiki.sh"
  exit 1
fi

cp "$REPO_DIR"/wiki/*.md "$TMP/wiki/"

git -C "$TMP/wiki" add -A
if git -C "$TMP/wiki" diff --cached --quiet; then
  info "La wiki ya está actualizada. No hay cambios."
  exit 0
fi

git -C "$TMP/wiki" -c user.name="${GIT_AUTHOR_NAME:-php2shell-agent}" \
  -c user.email="${GIT_AUTHOR_EMAIL:-noreply@localhost}" \
  commit -q -m "$MESSAGE"
git -C "$TMP/wiki" push --quiet origin HEAD
ok "Wiki publicada: https://github.com/latadeloco/agent-php2shell/wiki"
