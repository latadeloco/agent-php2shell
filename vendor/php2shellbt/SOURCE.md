# php2shellbt (copia vendorizada y parcheada)

- Origen: https://github.com/pentestershell/php2shellbt
- Autor: pentestershell (BTshell)
- Licencia: MIT (ver `LICENSE` en esta carpeta)
- Commit upstream: `621f557297f69a26ee7e28d21bc042b736725a63`
- SHA-256 del script upstream: `08ed5eed6dccb6ff5e7648ac62b50b98b765e856dc3df926666682ca6012049b`
- SHA-256 de esta copia parcheada: `0aec1b8df8959b8bc97a6bc333aa21644c5e9f9492dba49cf93fc4853b494398`

## Parches aplicados

- Verificación TLS activada por defecto; `--insecure` para desactivarla.
- Redirecciones desactivadas por defecto; `--follow-redirects` para permitirlas.
- Eliminadas las opciones de listas (`--targets`, `--lfi-list`, `--session-paths-list`, `--handler-pairs`).
- Añadido `--checks` para ejecutar solo las comprobaciones deseadas.
- `handler` y `lfi` exigen rutas explícitas; no se usan valores por defecto.
- Eliminada la impresión del payload PHP del check 4.
- Salida JSON pura con `--json`; los errores van a stderr.
- Colores desactivados cuando la salida no es una terminal o con `--no-color`.

El objetivo de estos cambios es reducir el impacto, evitar listas de objetivos y no exponer payloads en la salida del agente.
