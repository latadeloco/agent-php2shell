# Seguridad y permisos

Esta página explica los riesgos de usar la herramienta, qué permisos tiene el agente y cómo proteger la información de los informes.

## La prueba activa puede afectar al servidor

La prueba completa no es una simple consulta. Envía aproximadamente 29 MB en varias peticiones y está diseñada para comprobar si PHP falla al procesarlas.

En un servidor frágil puede provocar:

- Que PHP deje de responder durante unos segundos.
- Errores temporales 502, 503 o 504.
- Pérdida de peticiones que estuvieran en curso.

Por este motivo:

- Úsela solo en servidores propios o con autorización por escrito.
- Prefiera un entorno de pruebas o una ventana de mantenimiento.
- Asegúrese de saber cómo reiniciar el servicio de PHP si fuera necesario.
- No la ejecute en producción sin avisar a las personas responsables.

## Autorización

Antes de probar un dominio público, el agente le preguntará si es suyo o si tiene permiso.

Si el servidor pertenece a un cliente, obtenga la autorización por escrito. Si pertenece a un tercero, no lo pruebe.

Probar un servidor sin autorización puede tener consecuencias legales y técnicas.

## Qué permisos tiene el agente

El agente está diseñado para trabajar con permisos limitados:

- **No edita archivos.**
- **No navega por su cuenta.**
- **No ejecuta `sudo`.**
- Solo ejecuta los comandos internos de php2shell.
- La prueba activa exige una confirmación explícita.

El triaje es de solo lectura. No borra archivos, no cambia configuraciones y no intenta "limpiar" el servidor.

## La opción de simulación

El comando de escaneo incluye una opción de simulación que muestra lo que se ejecutaría sin enviar tráfico:

```bash
php2shell-scan.sh --dry-run -u https://ejemplo.example
```

Úsela si quiere revisar el comando antes de autorizar la prueba.

## Protección de los informes

Los informes pueden contener información sensible:

- Direcciones IP.
- Nombres de usuario y rutas internas.
- Nombres de servicios y conexiones.
- Fragmentos de registros del servidor.

Guarde los informes en un lugar seguro y no los publique. Si necesita compartirlos, revise antes su contenido y elimine los datos que no sean necesarios.

No pegue informes con datos internos en chats públicos, foros o repositorios abiertos.

## Contraseñas y cookies

En la mayoría de los casos no necesita proporcionar contraseñas, cookies ni claves.

Si el agente necesita una cabecera especial, evite pegarla en el chat. Tenga en cuenta que los comandos pueden quedar registrados en el historial de la terminal.

## Windows

En Windows, el agente funciona a través de Git Bash. No hay `sudo` ni los registros habituales de PHP en `/var/log`, por lo que el triaje verá menos información que en Linux.

Si Claude Code utiliza PowerShell sin Git Bash, los comandos internos del agente no podrán ejecutarse. Instale Git for Windows o utilice WSL.

## Módulo de defensa

Las reglas de defensa son opcionales:

- No se instalan por defecto.
- El perfil `alert` solo registra; `block` exige pedirlo.
- Se verifican por commit y SHA-256, y fallan cerrado.
- Solo escriben en `~/.local/share/php2shell-agent/vendor/rules/` o en el destino que se indique.
- Nunca tocan `/etc` ni usan `sudo`.
- Pueden dar falsos positivos; la regla de *chunked multipart* está excluida por defecto.

## Limitaciones

- La información de versión que anuncia el servidor puede ser falsa.
- Un resultado sin hallazgos no garantiza que el servidor sea seguro.
- La variante de fuga de memoria deja pocos rastros.
- Actualizar PHP no deshace un ataque anterior.
- El triaje puede no ver los registros de un contenedor Docker si se ejecuta en el equipo anfitrión.

## Si sospecha que ya ha habido un ataque

Consulte [Triaje](Triaje). Si aparecen señales de compromiso:

- Conserve los registros.
- Cambie las claves y contraseñas que puedan haberse visto afectadas.
- Contacte con una persona especializada en seguridad.
- No borre archivos ni "limpie" el servidor sin asesoramiento.

## Más información

- [Uso](Uso)
- [Resultados](Resultados)
- [Triaje](Triaje)
- [Preguntas frecuentes](Preguntas-frecuentes)
