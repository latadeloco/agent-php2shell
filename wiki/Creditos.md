# Créditos y fuentes

php2shell-agent se apoya en el trabajo de otras personas y equipos. Esta página reconoce su aportación.

## Fuentes principales

| Fuente | Aportación | Enlace |
|---|---|---|
| **Assetnote** | Escáner oficial de php2shell | https://github.com/assetnote/php2shell-scanner |
| **Sairahcaz** | Script de triaje de solo lectura | https://gist.github.com/Sairahcaz/2c22b4a68fd5b75e410c7f9f69f485a0 |
| **Equipo Calif** | Descubrimiento original de php2shell | https://calif.io/php2shell/ |

Fallos tratados:

- CVE-2026-109618
- CVE-2026-109619

## Versiones fijadas

Para que los resultados sean reproducibles, el instalador descarga versiones concretas:

- Escáner: commit `353545fe9e72ff85921a84cf396d71b3d15e936e`.
- Triaje: revisión `ec40176f383156c29a8fa3f60d4a88c82cb683a8`.
- Huella del triaje: SHA-256 `355a12feb009bc9a2071155c56eec38a67b0c3b9bfdc30014e36a198418b672d`.

El instalador verifica estas versiones antes de usarlas.

## Licencias

- El código propio de este repositorio tiene licencia MIT.
- El repositorio de Assetnote no incluye un archivo de licencia en la revisión utilizada.
- El gist de Sairahcaz no incluye licencia.
- Por este motivo, este proyecto **no copia ni redistribuye** su código. Solo lo descarga al instalar y verifica su integridad.

Consulte el archivo `SOURCES.md` del repositorio para más detalles.

## Afiliación

No existe afiliación, patrocinio ni respaldo por parte de Assetnote, Sairahcaz o el equipo Calif.

Las marcas y nombres pertenecen a sus respectivos propietarios.

## Cómo reportar un problema

Si encuentra un problema en este repositorio, abra un issue:

https://github.com/latadeloco/agent-php2shell/issues

Incluya:

- Sistema operativo.
- Herramienta utilizada (opencode, Claude Code, Codex, Gemini, genérica).
- Pasos para reproducir el problema.
- Mensaje de error relevante.

No incluya contraseñas, claves ni datos de servidores de terceros.

Si el problema está en el escáner de Assetnote o en el script de triaje, contacte con sus autores originales.

## Agradecimientos

Gracias a Assetnote por el escáner, a Sairahcaz por el script de triaje y al equipo Calif por el descubrimiento original.
