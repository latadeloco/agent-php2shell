# php2shell-agent

Bienvenido a la documentación de **php2shell-agent**, una herramienta que ayuda a comprobar si una página web o un proyecto PHP presenta dos fallos de seguridad conocidos:

- **CVE-2026-109618**
- **CVE-2026-109619**

También permite buscar señales de que esos fallos ya se hayan utilizado en el pasado.

Estas páginas están pensadas tanto para personas con perfil técnico como para personas que solo necesitan entender el resultado y saber qué hacer. No se supone conocimiento previo de seguridad informática.

## Qué puede hacer

- Revisar la versión de PHP que anuncia una web.
- Ejecutar una prueba real y controlada para confirmar si el fallo está presente.
- Guardar un informe claro con el resultado y los pasos recomendados.
- Revisar un servidor en busca de pistas de un posible ataque previo, sin modificar nada.
- Ofrecer reglas opcionales de defensa para WAF/IDS, sin instalar nada por defecto.
- Funcionar con distintas herramientas de inteligencia artificial: opencode, Claude Code, Codex, Gemini CLI y otras compatibles.

## Antes de empezar: aviso importante

La prueba completa es **activa** y **puede tumbar el servidor** durante unos segundos. Envía aproximadamente 29 MB y puede provocar que PHP deje de responder temporalmente.

Úsela únicamente en servidores propios o para los que tenga autorización por escrito. Si el servidor es de un cliente o de un tercero, confirme primero que tiene permiso.

La herramienta pide confirmación antes de ejecutar la prueba activa. Puede revisar el comando sin enviar tráfico mediante la opción de simulación.

## Empezar en tres pasos

1. [Instalar](Instalacion) la herramienta.
2. [Aprender a usarla](Uso) con Claude Code, opencode, Codex o Gemini.
3. [Entender el resultado](Resultados) y saber qué hacer.

## Guías

- [Instalación](Instalacion)
- [Uso](Uso)
- [Resultados](Resultados)
- [Seguridad y permisos](Seguridad)
- [Revisión de un posible ataque previo (triaje)](Triaje)
- [Problemas frecuentes](Problemas-frecuentes)
- [Preguntas frecuentes](Preguntas-frecuentes)
- [Glosario](Glosario)
- [Créditos y fuentes](Creditos)

## Qué necesita

Un ordenador con Linux, macOS o Windows, conexión a Internet y la herramienta `uv`, que se encarga de ejecutar el escáner. En Windows hace falta Git para Windows, que incluye Git Bash.

No hace falta saber programar para usar el agente, pero sí es recomendable saber abrir una terminal y ejecutar un comando.

## Una idea importante

Esta herramienta detecta dos fallos concretos. **No es una auditoría de seguridad completa** y no demuestra que un servidor sea seguro. Si el resultado indica que no se ha visto el fallo, significa únicamente que no se ha detectado con estas pruebas.
