# Créditos y fuentes

php2shell-agent se apoya en el trabajo de otras personas y equipos. Esta página reconoce su aportación.

## Fuentes principales

| Fuente | Aportación | Enlace |
|---|---|---|
| **Assetnote** | Escáner oficial de php2shell | https://github.com/assetnote/php2shell-scanner |
| **Sairahcaz** | Script de triaje de solo lectura | https://gist.github.com/Sairahcaz/2c22b4a68fd5b75e410c7f9f69f485a0 |
| **pentestershell (BTshell)** | Módulo de cadena de sesión y LFI | https://github.com/pentestershell/php2shellbt |
| **Syhunt (Felipe Daragon)** | Guía de mitigación y plantillas para CVE-2026-115560 | https://github.com/syhunt/php2shell-protection |
| **Equipo Calif** | Descubrimiento original de php2shell | https://calif.io/php2shell/ |
| **Qi Deng (ikow) / GoldraK** | Reglas de defensa (Suricata, Sigma, ModSecurity, Lua) | https://github.com/GoldraK/php2shell-poc |

Fallos tratados:

- CVE-2026-109618
- CVE-2026-109619
- CVE-2026-115560 (auditoría de configuración local; no detección remota)

## Versiones fijadas

Para que los resultados sean reproducibles, el instalador descarga versiones concretas:

- Escáner: commit `353545fe9e72ff85921a84cf396d71b3d15e936e`.
- Triaje: revisión `ec40176f383156c29a8fa3f60d4a88c82cb683a8`.
- Huella del triaje: SHA-256 `355a12feb009bc9a2071155c56eec38a67b0c3b9bfdc30014e36a198418b672d`.
- Cadena de sesión: commit `621f557297f69a26ee7e28d21bc042b736725a63`; SHA-256 parcheado `0aec1b8df8959b8bc97a6bc333aa21644c5e9f9492dba49cf93fc4853b494398`.
- Reglas de defensa: commit `93df49253e79774e61833938c40aff3b79c6bde1` y SHA-256 por fichero.

El instalador verifica estas versiones antes de usarlas.

## Licencias

- El código propio de este repositorio tiene licencia MIT.
- El repositorio de Assetnote no incluye un archivo de licencia en la revisión utilizada.
- El gist de Sairahcaz no incluye licencia.
- `php2shellbt` usa licencia MIT y se incluye vendorizado, con su licencia y los parches documentados.
- La guía de Syhunt usa licencia MIT; se enlaza y no se vendoriza.
- Por este motivo, este proyecto **no copia ni redistribuye** el scanner ni el gist. Solo los descarga al instalar y verifica su integridad.

Consulte el archivo `SOURCES.md` del repositorio para más detalles.

## Afiliación

No existe afiliación, patrocinio ni respaldo por parte de Assetnote, Sairahcaz, pentestershell, Syhunt, el equipo Calif ni Qi Deng.

Las reglas de defensa no están auditadas por el vendor. El repositorio de origen incluye PoC de explotación que este proyecto no descarga ni redistribuye.

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
