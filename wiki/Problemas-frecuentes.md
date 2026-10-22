# Problemas frecuentes

Esta página recoge los problemas más habituales y cómo resolverlos.

## No encuentra `uv`

**Mensaje:** `Falta 'uv', la herramienta que ejecuta el scanner.`

`uv` es el programa que ejecuta el escáner. Instálelo:

- Linux o macOS:

  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

- Windows, desde PowerShell:

  ```powershell
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  ```

Cierre y vuelva a abrir la terminal. Compruebe con `uv --version`.

## En Windows no funciona el instalador

El instalador necesita **Git Bash**, que viene con Git for Windows.

- Si ejecuta el instalador desde PowerShell, ábralo desde **Git Bash**.
- Si Claude Code usa PowerShell, instale Git for Windows.
- Si Claude Code no encuentra Git Bash, añada esta configuración a `settings.json`:

  ```json
  {
    "env": {
      "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe"
    }
  }
  ```

También puede usar WSL 2. Consulte [Instalación](Instalacion).

## El agente no aparece en Claude Code

1. Compruebe que el archivo existe:

   ```text
   C:\Users\<su-usuario>\.claude\agents\php2shell.md
   ```

   En Linux o macOS:

   ```text
   ~/.claude/agents/php2shell.md
   ```

2. Reinicie Claude Code. Si la carpeta `agents` no existía al iniciar la sesión, Claude Code necesita reiniciarse para detectarla.
3. Compruebe que está usando el subagente `php2shell` y no un comando con barra.

## El agente no aparece en opencode

Compruebe:

```bash
opencode agent list
```

Debe aparecer `php2shell`. Si no aparece, vuelva a ejecutar:

```bash
./install.sh --target opencode --yes
```

## Error `Model not found`

El modelo indicado no existe en su instalación.

- Ejecute el instalador sin `--model` para heredar el modelo configurado en su herramienta.
- O indique un modelo que exista. Por ejemplo, en opencode:

  ```bash
  ./install.sh --target opencode --model deepseek/deepseek-flash --yes
  ```

En Claude Code, use un alias como `sonnet`, `opus` o `haiku`, o no indique modelo.

## El instalador pide confirmación y no hay terminal

**Mensaje:** `No hay terminal interactiva para confirmar. Usa --yes.`

Añada `--yes` al comando:

```bash
./install.sh --target claude-code --yes
```

## La web devuelve 404

Un 404 en la dirección principal no significa que el servidor sea vulnerable o seguro. Puede que la aplicación esté en otra ruta.

Indique al agente la ruta correcta, por ejemplo:

```text
La aplicación está en https://mi-web.example/public/index.php
```

El agente puede probar una ruta concreta.

## El escaneo devuelve 502 o el servidor deja de responder

Es una posibilidad conocida de la prueba activa. PHP puede haberse detenido al procesar la prueba.

- Espere unos segundos.
- Compruebe si el servicio se ha recuperado.
- Si no se recupera, reinicie PHP-FPM o el contenedor correspondiente.
- No repita la prueba inmediatamente.

## El escaneo tarda demasiado o se corta

Puede ocurrir si hay un cortafuegos, un proxy o una protección que bloquea las peticiones.

- Compruebe que la dirección es correcta.
- Pruebe primero la comprobación rápida.
- Revise si el servidor bloquea peticiones grandes.
- No repita la prueba muchas veces seguidas.

## `sha256sum: command not found` en macOS

En macOS el comando equivalente es `shasum`. La herramienta lo detecta automáticamente, pero si ejecuta comandos a mano, use:

```bash
shasum -a 256 archivo
```

## No veo registros de PHP en el triaje

Puede ocurrir por varios motivos:

- No hay permisos suficientes. Ejecute el triaje con `sudo` manualmente.
- El servidor usa Docker y los registros están dentro del contenedor.
- El servidor no escribe registros de PHP en las rutas habituales.
- Está en Windows, donde no existen las rutas de Linux.

## El resultado es FIXED pero sigo preocupado

`FIXED` significa que la versión parece corregida y que la prueba no ha reproducido el fallo. No es una garantía absoluta.

Si sospecha que ha habido un ataque, ejecute el [Triaje](Triaje). Si hay señales de compromiso, contacte con seguridad profesional.

## He visto un FLAG en el triaje

No borre archivos ni "limpie" el servidor. Conserve los registros, cambie las claves que puedan haberse visto afectadas y busque ayuda profesional. Consulte [Triaje](Triaje).

## Otros problemas

Si el problema no aparece aquí, abra un issue en el repositorio con:

- Sistema operativo.
- Herramienta utilizada.
- Mensaje de error.
- Pasos para reproducirlo.

No incluya contraseñas, claves ni datos de servidores de terceros.
