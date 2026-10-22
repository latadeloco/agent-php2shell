# Seguridad

## Alcance

`php2shell-agent` ayuda a detectar y triar dos fallos concretos de PHP:

- CVE-2026-109618
- CVE-2026-109619

No es una auditoría de seguridad completa ni sustituye una revisión profesional.

## Prueba activa

El scanner envía una petición de control y hasta tres sondas de 1 a 20 MiB (unas 29 MiB en total). En servidores frágiles puede provocar:

- caída temporal de workers PHP-FPM;
- errores 502/503/504;
- pérdida de peticiones en curso.

Por eso:

- Solo debe usarse en servidores propios o con autorización por escrito.
- El wrapper exige `--i-have-permission`.
- `--dry-run` permite revisar el comando sin enviar tráfico.
- El agente pide confirmación explícita antes de ejecutar.
- Se recomienda probar primero en staging y en horario de baja carga.

## Triaje

El triaje es de solo lectura. Lee versiones de PHP, logs, archivos del webroot, crons, claves SSH y conexiones de red. No borra malware, no cambia configuraciones y no "limpia" el servidor.

La salida puede contener información sensible:

- direcciones IP;
- usuarios y rutas internas;
- nombres de servicios y conexiones;
- fragmentos de logs.

Guarda los informes en local y no los publiques. No pegues salidas con `sudo` en sitios públicos.

## Datos y permisos

- El agente no edita archivos, no navega por su cuenta y no ejecuta `sudo`.
- El triaje con `sudo` solo se muestra como comando manual para que lo lance la persona.
- Los wrappers escriben únicamente en `~/.local/state/php2shell-scans/`.
- Los scripts descargados se verifican por commit o SHA-256 antes de usarse.

## Módulo de defensa

Las reglas de defensa son opcionales y no forman parte del flujo de detección:

- No se instalan por defecto: exigen `--install`.
- Se descargan con commit fijado y SHA-256 por fichero; si no coincide, fallan cerrado.
- El perfil por defecto es `alert`: registra pero no bloquea. `block` exige pedirlo de forma explícita.
- Solo escriben en el destino indicado (por defecto, dentro de `~/.local/share/php2shell-agent/`). Nunca en `/etc` ni con `sudo`.
- No incluyen PoC ni exploits; son firmas de detección.
- Pueden generar falsos positivos. La regla de *chunked multipart* queda excluida salvo con `--include-aggressive`.

La auditoría de sesión es de solo lectura y se ejecuta dentro del triaje. Si no puede leer sesiones o logs, lo indica y no altera el veredicto ni el código de salida.

## Limitaciones

- `X-Powered-By` puede faltar o ser falseado.
- Un `NO SIGNAL` en las reglas de defensa no significa que no haya habido intentos; dependen de que existan logs.
- `NO SIGNAL` no significa "seguro".
- La variante de fuga de memoria deja pocos rastros en disco.
- Actualizar PHP no deshace un compromiso anterior.
- El triaje puede no ver logs de contenedores Docker si se ejecuta en el host.

## Reportar un problema

Si encuentras un fallo en este repositorio (no en php2shell), abre un issue privado o contacta con la persona mantenedora. Incluye:

- versión del repositorio;
- sistema operativo;
- herramienta usada (opencode, Claude Code, Codex, Gemini, genérico);
- pasos para reproducirlo;
- salida relevante, sin secretos ni datos personales.

No publiques exploits funcionales ni datos de servidores de terceros.
