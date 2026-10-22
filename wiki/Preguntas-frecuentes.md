# Preguntas frecuentes

## ¿Esta herramienta es una auditoría de seguridad completa?

No. Solo comprueba dos fallos concretos:

- CVE-2026-109618
- CVE-2026-109619

Un resultado sin hallazgos no significa que el servidor sea seguro.

## ¿La prueba ataca realmente al servidor?

Sí. La prueba completa envía peticiones reales y puede hacer que PHP falle. Por eso debe usarse solo con autorización.

No intenta obtener acceso, ejecutar código malicioso ni instalar nada. Comprueba si el fallo está presente.

## ¿Puede tumbar el servidor?

Puede provocar que PHP deje de responder durante unos segundos. En un servidor frágil puede causar errores temporales. Por eso se recomienda probar primero en un entorno de pruebas.

## ¿La herramienta cambia algo en el servidor?

El escaneo no modifica archivos ni configuraciones. La prueba activa puede provocar un fallo temporal en PHP.

El triaje es de solo lectura: no cambia nada.

## ¿Necesito instalar algo en el servidor?

No. El agente se ejecuta en su ordenador y se conecta al servidor por la red.

Para el triaje, el script debe ejecutarse en el servidor que se quiere revisar. Si es remoto, ejecútelo allí.

## ¿Funciona en Windows?

Sí, con **Git for Windows** (Git Bash) o con **WSL 2**.

Si Claude Code usa PowerShell sin Git Bash, los scripts del agente no podrán ejecutarse. Instale Git for Windows o use WSL.

## ¿Funciona con Claude, ChatGPT, Gemini o DeepSeek?

Sí. El agente puede instalarse en:

- opencode
- Claude Code
- Codex
- Gemini CLI
- Cualquier herramienta compatible con `AGENTS.md`

El modelo de inteligencia artificial se configura en cada herramienta. Si no se indica uno, el agente hereda el modelo que ya esté configurado.

## ¿Es gratis?

El código de este repositorio tiene licencia MIT. El escáner de Assetnote y el script de triaje de Sairahcaz no se redistribuyen y conservan sus propios términos. Consulte [Créditos y fuentes](Creditos).

## ¿Envía mis datos a algún sitio?

El agente se conecta al servidor que usted indique para hacer las comprobaciones. Los informes se guardan en su ordenador.

No envíe informes con datos internos a servicios públicos ni a terceros.

## ¿Por qué el agente responde tan breve?

Para reducir el consumo de tokens y facilitar la lectura. Por defecto responde en 10–12 líneas y no repite la salida de las herramientas.

Si necesita más detalle, escriba **“detalle”**, **“explica más”** o **“informe completo”**. Los informes guardados siempre contienen toda la información.

## ¿Qué significa NO SIGNAL?

Significa que no se ha visto el fallo, pero que no hay información suficiente para confirmar que esté corregido. **No significa que el servidor sea seguro.**

## ¿Qué significa FIXED?

Significa que la versión de PHP parece corregida y que la prueba no ha reproducido el fallo. Es una buena señal, pero no una garantía absoluta.

## ¿Qué significa VULNERABLE?

Significa que el fallo está presente. Debe actualizar PHP y volver a probar.

## ¿Puedo probar la web de un cliente?

Solo si tiene autorización por escrito. Si no está seguro, no lo haga.

## ¿Puedo usarlo en producción?

Sí, pero con precaución. La prueba activa puede afectar al servicio. Use una ventana de mantenimiento, avise a las personas responsables y asegúrese de saber cómo reiniciar PHP.

## ¿Puedo usarlo en integración continua?

No se recomienda lanzar la prueba activa automáticamente. Los tests del repositorio no realizan escaneos activos.

## ¿Qué hago si el triaje muestra FLAG?

Conserve los registros, cambie las claves que puedan haberse visto afectadas y contacte con una persona especializada. No borre archivos ni "limpie" el servidor a ciegas.

## ¿Dónde se guardan los informes?

En:

```text
~/.local/state/php2shell-scans/
```

## ¿Cómo desinstalo el agente?

```bash
cd agent-php2shell
./uninstall.sh
```

Para borrar también el escáner y los informes:

```bash
./uninstall.sh --purge
```

## ¿Dónde puedo consultar los términos y las fuentes?

Consulte [Créditos y fuentes](Creditos) y el archivo `SOURCES.md` del repositorio.
