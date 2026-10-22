# Uso

Esta página explica cómo pedir al agente que revise una web o un proyecto, qué preguntas hará y qué puede esperar en cada paso.

> **Recuerde:** la prueba completa es activa y puede tumbar el servidor unos segundos. Úsela solo con autorización y, preferiblemente, en un entorno de pruebas o en una ventana de mantenimiento.

## Modo breve

Por defecto, el agente responde en **10–12 líneas** y no repite la salida de las herramientas. Los informes guardados contienen toda la información.

Si necesita más contexto, pida **“detalle”**, **“explica más”** o **“informe completo”**. El agente ampliará solo la parte que solicite.

## Antes de empezar

Tenga a mano:

- La dirección de la web que desea revisar, por ejemplo `https://mi-web.example`.
- O la carpeta del proyecto, si va a revisar una instalación local.
- La confirmación de que tiene permiso para probar ese servidor.

No hace falta pegar contraseñas, cookies ni claves. En la mayoría de los casos no son necesarias.

## Cómo pedir una revisión

Abra su herramienta y hable con el agente:

- **opencode:** seleccione `php2shell` con la tecla Tab o escriba `@php2shell`.
- **Claude Code:** pida el subagente `php2shell`.
- **Codex:** pida el subagente `php2shell`.
- **Gemini:** ejecute `/php2shell`.

Ejemplos de peticiones:

```text
Revisa si https://mi-web.example tiene php2shell.
```

```text
Revisa este proyecto PHP y dime si la versión de PHP está corregida.
```

```text
El escaneo ha salido vulnerable. ¿Puedes revisar si hay señales de un ataque?
```

## Qué hará el agente, paso a paso

### 1. Revisión previa

El agente comprobará que las herramientas necesarias están instaladas, que los archivos son los correctos y que sus permisos son seguros.

También le mostrará una lista de lo que va a usar y le pedirá un primer visto bueno.

### 2. Comprobación rápida

El agente hará una petición normal a la web para leer la versión de PHP que anuncia el servidor. No envía nada pesado.

Esta comprobación puede indicar si la versión está desactualizada, pero no siempre es fiable: algunos servidores ocultan esa información o la muestran de forma incorrecta.

### 3. Confirmación

Antes de la prueba completa, el agente le explicará:

- Qué va a comprobar.
- Cuánto va a enviar.
- Qué puede ocurrir.
- Cuánto tiempo puede tardar.

Después le pedirá permiso. Si duda o no confirma, el agente se detendrá.

En Claude Code, como los subagentes no tienen una ventana de pregunta, el agente le pedirá que escriba la frase exacta:

```text
CONFIRMO QUE TENGO PERMISO
```

### 4. Revisión del comando

El agente mostrará el comando exacto que se ejecutaría, sin enviar tráfico. Así puede ver qué va a ocurrir antes de aceptar.

### 5. Prueba completa

Solo si ha dado permiso, el agente enviará las pruebas. Envía aproximadamente 29 MB y puede provocar que PHP deje de responder unos segundos.

Mientras se ejecuta, no cierre la terminal. Si el servidor devuelve errores temporales, es posible que el agente lo indique en el informe.

### 6. Informe

Al terminar, recibirá un informe con:

- Un resumen en lenguaje sencillo.
- El resultado de la prueba.
- Los pasos recomendados.
- Un anexo técnico con la ruta del informe guardado.

## Cómo detener el proceso

- Si el agente le hace una pregunta, responda que no o cancele.
- Si ya se está ejecutando la prueba, pulse `Ctrl+C` en la terminal.
- Si no está seguro, no continúe y consulte con la persona responsable del servidor.

## Revisar un proyecto local

Si el proyecto está en su ordenador:

1. Indique la carpeta del proyecto.
2. El agente leerá los archivos de configuración y ejecutará `php -v` si está disponible.
3. Le dirá qué versión de PHP parece usar el proyecto.
4. Le pedirá la dirección donde está funcionando, por ejemplo `http://localhost:8000`.
5. Con esa dirección, seguirá el flujo normal.

El agente no arranca la aplicación por su cuenta.

## Defensa opcional (WAF/IDS)

Si el resultado es **VULNERABLE** o lo pide, el agente puede dejarle reglas de detección para Suricata/Snort, Sigma, ModSecurity y OpenResty. Son opcionales:

- Por defecto solo **alertan**; no bloquean.
- El perfil `block` solo se usa si lo pide y asume el riesgo de falsos positivos.
- Se descargan con commit y hash fijados; si no coinciden, no se instalan.
- Nunca modifican configuraciones del sistema ni usan `sudo`.
- No incluyen exploits: son firmas para detectar intentos.

El agente solo le dará la ruta; no vuelca las firmas en el chat.

## Qué no debe hacer

- No pruebe servidores de terceros sin autorización por escrito.
- No pegue contraseñas, cookies de sesión ni claves privadas.
- No interprete un resultado sin hallazgos como una garantía de seguridad.
- No ejecute la prueba activa en producción sin una ventana de mantenimiento y sin saber cómo reiniciar el servicio de PHP.

## Siguiente paso

Consulte [Resultados](Resultados) para entender qué significa cada veredicto y qué hacer después.
