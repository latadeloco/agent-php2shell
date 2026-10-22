# Fuentes y procedencia

Este repositorio **no redistribuye** el scanner ni el script de triaje. El instalador los descarga desde su origen, fija una versión concreta y verifica su integridad.

| Componente | Autor | Origen | Versión fijada | Integridad |
|---|---|---|---|---|
| Scanner php2shell | Assetnote Security Research Team | https://github.com/assetnote/php2shell-scanner | commit `353545fe9e72ff85921a84cf396d71b3d15e936e` | `git rev-parse HEAD` |
| Triaje de solo lectura | Sairahcaz | https://gist.github.com/Sairahcaz/2c22b4a68fd5b75e410c7f9f69f485a0 | revisión `ec40176f383156c29a8fa3f60d4a88c82cb683a8` | SHA-256 `355a12feb009bc9a2071155c56eec38a67b0c3b9bfdc30014e36a198418b672d` |
| Descubrimiento original | Equipo Calif | https://calif.io/php2shell/ | — | — |

CVEs tratados:

- CVE-2026-109618
- CVE-2026-109619

## Licencias

- El código propio de este repositorio usa licencia MIT (ver `LICENSE`).
- El repositorio de Assetnote **no incluye un archivo de licencia** en la revisión fijada.
- El gist de Sairahcaz **no incluye licencia**.
- Por ese motivo, este proyecto no copia ni redistribuye su código. Solo lo descarga al instalar y verifica el hash.
- No hay afiliación, patrocinio ni respaldo por parte de Assetnote, Sairahcaz ni Calif.

Si eres autor de alguno de esos proyectos y quieres que se ajuste la atribución o el método de instalación, abre un issue en este repositorio.
