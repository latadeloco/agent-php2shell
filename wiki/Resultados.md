# Resultados

Esta página explica qué significan los resultados del escaneo y qué hacer en cada caso.

## Los cinco resultados posibles

| Resultado | Qué significa | Qué debe hacer |
|---|---|---|
| **VULNERABLE** | El servidor tiene el fallo. La prueba ha conseguido que PHP falle o la versión anunciada está por debajo de la corregida. | Actualizar PHP cuanto antes, reiniciar el servicio y volver a probar. |
| **FIXED** | La versión de PHP indica que el fallo está corregido y no se ha visto el fallo en la prueba. | Mantener PHP actualizado. No es una garantía absoluta. |
| **NO SIGNAL** | No se ha visto el fallo, pero el servidor no ha dado información suficiente. | No asumir que está seguro. Repetir con la ruta correcta o revisar la versión de PHP. |
| **INCONCLUSIVE** | El servidor ha bloqueado, cortado o rechazado la prueba antes de terminar. | Revisar si hay un cortafuegos o una protección que lo impida. |
| **ERROR** | No se ha podido conectar con la dirección indicada. | Revisar la dirección, el DNS, el certificado o la red. |

## Versiones de PHP corregidas

| Rama de PHP | Versión corregida o superior |
|---|---|
| PHP 8.2 | 8.2.35 |
| PHP 8.3 | 8.3.36 |
| PHP 8.4 | 8.4.27 |
| PHP 8.5 | 8.5.12 |

Si su versión es anterior a la de su rama, está desactualizada.

## Qué significa "VULNERABLE"

El agente ha confirmado que el fallo está presente. Puede haber ocurrido de dos formas:

- La prueba ha hecho que el proceso de PHP fallara. El servidor puede haber devuelto un error temporal, como el error 502.
- La versión de PHP anunciada por el servidor está por debajo de la versión corregida.

Un error 502 significa que el servidor web no ha podido comunicarse con PHP porque el proceso de PHP se ha detenido. Es una señal seria, aunque el servicio suele recuperarse solo o al reiniciarse.

## Qué hacer si el resultado es VULNERABLE

1. Actualice PHP a la versión corregida de su rama.
2. Reinicie el servicio de PHP o el contenedor que lo ejecute.
3. Vuelva a ejecutar la prueba para confirmar.
4. Si no puede actualizar de inmediato:
   - Avisar a la persona responsable del servidor.
   - Valorar poner el sitio en mantenimiento.
   - Restringir el acceso a paneles como phpMyAdmin.
   - Evitar exponer el servidor a Internet sin protección.

No borre archivos ni "limpie" el servidor a ciegas. Si sospecha que el fallo ya se ha utilizado, consulte [Triaje](Triaje).

## Qué significa "FIXED"

La versión anunciada por el servidor es igual o superior a la corregida y la prueba no ha reproducido el fallo.

Esto es una buena señal, pero no una garantía absoluta:

- La información de versión puede ser incorrecta.
- Puede haber otros fallos distintos.
- La prueba solo comprueba estos dos problemas concretos.

## Qué significa "NO SIGNAL"

No se ha visto el fallo, pero tampoco hay información suficiente para confirmar que esté corregido. Por ejemplo, el servidor puede ocultar la versión de PHP.

**NO SIGNAL no significa que el servidor sea seguro.** Significa que estas pruebas no han encontrado evidencia.

## Dónde se guarda el informe

Los informes se guardan en:

```text
~/.local/state/php2shell-scans/
```

Hay dos tipos de archivo:

- Un archivo `.json` con el resultado del escáner.
- Un archivo `.txt` con el resultado del triaje, si se ha ejecutado.

El agente le indicará la ruta exacta al terminar. El chat muestra un resumen; los archivos contienen el detalle completo.

## Sobre los códigos de salida

Si utiliza los comandos directamente, el escáner devuelve:

- `0`: no se ha detectado el fallo.
- `1`: se ha detectado el fallo.
- `2`: no se ha podido guardar el informe.

No es necesario memorizarlos: el agente los traduce en el informe.

## Una advertencia final

Este escáner solo busca dos fallos concretos. Un resultado sin hallazgos no sustituye una auditoría de seguridad completa.

Si necesita una revisión profunda, contacte con un profesional de seguridad.
