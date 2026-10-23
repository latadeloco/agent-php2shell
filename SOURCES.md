# Fuentes y procedencia

Este repositorio **no redistribuye** el scanner de Assetnote ni el script de triaje de Sairahcaz: el instalador los descarga desde su origen, fija una versión concreta y verifica su integridad. El módulo `php2shellbt` sí se vendoriza porque su licencia MIT lo permite.

| Componente | Autor | Origen | Versión fijada | Integridad |
|---|---|---|---|---|
| Scanner php2shell | Assetnote Security Research Team | https://github.com/assetnote/php2shell-scanner | commit `353545fe9e72ff85921a84cf396d71b3d15e936e` | `git rev-parse HEAD` |
| Triaje de solo lectura | Sairahcaz | https://gist.github.com/Sairahcaz/2c22b4a68fd5b75e410c7f9f69f485a0 | revisión `ec40176f383156c29a8fa3f60d4a88c82cb683a8` | SHA-256 `355a12feb009bc9a2071155c56eec38a67b0c3b9bfdc30014e36a198418b672d` |
| Cadena de sesión + LFI | pentestershell (BTshell) | https://github.com/pentestershell/php2shellbt | commit `621f557297f69a26ee7e28d21bc042b736725a63` | SHA-256 parcheado `0aec1b8df8959b8bc97a6bc333aa21644c5e9f9492dba49cf93fc4853b494398` |
| Descubrimiento original | Equipo Calif | https://calif.io/php2shell/ | — | — |
| Reglas de defensa | Qi Deng (ikow) / fork GoldraK | https://github.com/GoldraK/php2shell-poc | commit `93df49253e79774e61833938c40aff3b79c6bde1` | SHA-256 por fichero (ver `scripts/lib.sh`) |

CVEs tratados:

- CVE-2026-109618
- CVE-2026-109619

## Licencias

- El código propio de este repositorio usa licencia MIT (ver `LICENSE`).
- El repositorio de Assetnote **no incluye un archivo de licencia** en la revisión fijada.
- El gist de Sairahcaz **no incluye licencia**.
- Por ese motivo, este proyecto no copia ni redistribuye el scanner ni el gist. Solo los descarga al instalar y verifica el hash.
- `php2shellbt` usa licencia **MIT** y se incluye vendorizado en `vendor/php2shellbt/`, con su licencia y las modificaciones documentadas en `vendor/php2shellbt/SOURCE.md`.
- Las reglas del fork de GoldraK no están auditadas por el vendor. Son firmas de detección; el repositorio de origen también incluye PoC de explotación que este proyecto **no descarga ni redistribuye**.
- No hay afiliación, patrocinio ni respaldo por parte de Assetnote, Sairahcaz, Calif, Qi Deng ni pentestershell.

Si eres autor de alguno de esos proyectos y quieres que se ajuste la atribución o el método de instalación, abre un issue en este repositorio.
