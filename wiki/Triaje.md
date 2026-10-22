# Revisión de un posible ataque previo (triaje)

El triaje es una revisión de **solo lectura** que busca señales de que alguien ya haya aprovechado el fallo php2shell en un servidor.

No es lo mismo que el escáner:

- El **escáner** comprueba si el fallo está presente ahora.
- El **triaje** busca pistas de un ataque anterior.

El triaje no modifica el servidor, no borra archivos y no repara nada.

## Cuándo utilizarlo

El agente lo ofrecerá cuando:

- El escaneo haya dado como resultado **VULNERABLE**.
- Usted pregunte si le han hackeado o si el servidor está comprometido.
- Quiera revisar un servidor de producción sin lanzar la prueba activa.

También puede solicitarlo directamente.

## Qué revisa

- Versiones de PHP instaladas en el equipo.
- Registros de PHP y del servidor web en busca de errores de memoria.
- Volumen de peticiones POST y destinos más frecuentes.
- Archivos PHP modificados o colocados en lugares inesperados.
- Tareas programadas, claves SSH y conexiones de red.

El triaje revisa **el equipo completo**, no solo la carpeta del proyecto.

## Cómo se ejecuta

El agente puede ejecutarlo sin privilegios de administrador:

```bash
~/.local/share/php2shell-agent/tools/php2shell-triage.sh /ruta/al/proyecto
```

Si no se indica una ruta, se utiliza el directorio actual.

El resultado se guarda en:

```text
~/.local/state/php2shell-scans/
```

### Ejecución con permisos de administrador

Algunos registros solo se pueden leer con permisos elevados. Si el agente no puede acceder a ellos, le mostrará un comando para que lo ejecute usted mismo:

```bash
sudo bash ~/.local/share/php2shell-agent/tools/vendor/php2shell-triage.sh /ruta/al/proyecto
```

El agente nunca ejecuta `sudo` por su cuenta.

En Windows no existe `sudo` ni los registros habituales de PHP en `/var/log`. El triaje funcionará, pero verá menos información.

## Cómo interpretar el resultado

| Resultado | Qué significa | Qué hacer |
|---|---|---|
| **FLAG** | Hay señales compatibles con un compromiso. No es una prueba definitiva, pero conviene tratarlo como sospechoso. | Conservar registros, cambiar claves y contactar con seguridad profesional. |
| **warn** | Hay elementos que conviene revisar, pero no son prueba de un ataque. | Revisar cada aviso con calma. |
| **Clean** | No se han visto señales en lo que el script puede leer. | No garantiza que el servidor esté limpio. |

El aviso `not running as root` significa que faltan permisos para leer algunos registros. **No es un problema de seguridad** y no debe contarse como hallazgo.

## Qué hacer si aparece FLAG

1. No borre archivos ni "limpie" el servidor a ciegas.
2. Conserve los registros y los informes.
3. Cambie las claves y contraseñas que puedan haberse visto afectadas, por ejemplo:
   - Clave de la aplicación.
   - Credenciales de la base de datos.
   - Claves de API.
   - Claves de certificados.
4. Contacte con una persona especializada en seguridad.
5. Actualice PHP, aunque la actualización no deshaga un ataque anterior.

## Limitaciones

- La variante de fuga de memoria deja pocos rastros en disco.
- Actualizar PHP no elimina un acceso que ya se haya producido.
- El triaje puede no ver los registros de un contenedor Docker si se ejecuta en el equipo anfitrión.
- Las fechas internas del script son fijas; si se ejecuta mucho después del incidente, la lista de archivos modificados puede incluir cambios normales.

## Privacidad

La salida puede contener direcciones IP, usuarios, rutas y conexiones. Guárdela en local y no la publique.

## Más información

- [Resultados](Resultados)
- [Seguridad y permisos](Seguridad)
- [Problemas frecuentes](Problemas-frecuentes)
