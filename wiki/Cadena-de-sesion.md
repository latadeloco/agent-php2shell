# Cadena de sesión avanzada

Esta página explica la prueba opcional que revisa la cadena de sesión de php2shell. Es más intrusiva que el escaneo habitual y debe usarse solo en entornos autorizados.

## Qué añade

El escaneo principal comprueba si el fallo está presente. Esta prueba avanzada busca tres cosas adicionales:

1. **Avisos de sesión:** indica si PHP muestra errores relacionados con `session.upload_progress`.
2. **Handler mismatch:** comprueba si dos endpoints usan configuraciones de sesión distintas y permiten una confusión de deserialización.
3. **Sesión + LFI:** comprueba si se puede escribir un marcador en un fichero de sesión y ejecutarlo a través de una inclusión de ficheros.

## Antes de usarla

Necesita:

- Autorización por escrito sobre el servidor.
- La ruta exacta del LFI, por ejemplo `/vuln.php?page=`.
- La ruta donde PHP guarda las sesiones, por ejemplo `/tmp/sessions/sess_`.
- Los dos endpoints para el handler mismatch, si va a probar esa parte.

No se admiten listas de objetivos. Cada ejecución prueba un único servidor.

> **Aviso:** la comprobación de sesión + LFI escribe un fichero de sesión y envía un marcador PHP al servidor. No es una prueba pasiva y puede dejar rastros. No la use en producción sin una ventana de mantenimiento y sin autorización.

## Cómo se ejecuta

El agente la ofrece después de un resultado **VULNERABLE** o si se solicita. También puede ejecutarla manualmente:

```bash
# Solo avisos de sesión
~/.local/share/php2shell-agent/tools/php2shell-bt.sh \
  --i-have-permission -u https://ejemplo.example --checks warn

# Cadena completa con rutas explícitas
~/.local/share/php2shell-agent/tools/php2shell-bt.sh \
  --i-have-permission --advanced -u https://ejemplo.example \
  --lfi "/vuln.php?page=" --session-path /tmp/sessions/sess_ \
  --write-path /upload.php --read-path /api/data.php
```

Antes de ejecutar, puede revisar el comando sin enviar tráfico:

```bash
~/.local/share/php2shell-agent/tools/php2shell-bt.sh \
  --dry-run -u https://ejemplo.example --checks warn
```

## Qué significan los resultados

| Resultado | Significado |
|---|---|
| **VULNERABLE** | La comprobación ha encontrado la señal correspondiente. |
| **NOT_FOUND** | No se ha encontrado la señal en esa prueba. No descarta el fallo. |
| **SKIPPED** | La comprobación no se ha ejecutado porque faltaban rutas o no se seleccionó. |

Un `NOT_FOUND` no significa que el servidor sea seguro: algunas señales solo aparecen si el servidor muestra errores en las respuestas.

## Qué hacer si aparece VULNERABLE

1. Actualice PHP a la versión corregida de su rama.
2. Revise la configuración de sesiones:
   - Desactive `session.upload_progress` si no lo necesita.
   - Active `session.upload_progress.cleanup`.
   - Active `session.use_strict_mode`.
3. Asegúrese de que todos los endpoints usan el mismo `session.serialize_handler`.
4. Revise y restrinja cualquier parámetro de inclusión de ficheros.
5. Considere reglas de defensa en el WAF o proxy.
6. Si sospecha que ya ha habido un ataque, ejecute el [Triaje](Triaje).

## Límites

- Requiere rutas exactas; el agente no las adivina.
- La comprobación de avisos depende de que el servidor muestre errores.
- La prueba no sustituye una auditoría completa.
- Puede dejar ficheros de sesión en el servidor.
- El módulo verifica TLS por defecto y no sigue redirecciones.

## Privacidad

El informe puede contener rutas internas y resultados de la sesión. Guárdelo en local y no lo publique.

## Créditos

La comprobación avanzada se basa en [pentestershell/php2shellbt](https://github.com/pentestershell/php2shellbt), con licencia MIT. La copia incluida está parcheada para verificar TLS, no seguir redirecciones, no aceptar listas y no mostrar payloads. Consulte [Créditos y fuentes](Creditos).

## Más información

- [Uso](Uso)
- [Resultados](Resultados)
- [Seguridad y permisos](Seguridad)
- [Triaje](Triaje)
