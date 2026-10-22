# Instalación

Esta guía explica cómo instalar **php2shell-agent** en su ordenador. No es necesario instalar el agente en el servidor que se va a revisar: el agente se ejecuta en su equipo y se conecta al servidor por la red.

> **Aviso:** la prueba completa es activa y puede tumbar el servidor unos segundos. Instalar la herramienta no ejecuta ninguna prueba. Las pruebas se lanzan después, siempre con confirmación y autorización.

## Lo que necesita

- Linux, macOS, Windows o WSL.
- `git`, `curl` y `bash`.
- `uv`, la herramienta que ejecuta el escáner de PHP.
- En Windows, **Git for Windows**, que incluye Git Bash.

`uv` es un programa que descarga y ejecuta el escáner con sus dependencias. No es necesario instalar Python a mano.

## Windows

Claude Code en Windows puede usar dos entornos:

- **Git Bash**, que viene con Git for Windows.
- **WSL 2**, que es un pequeño Linux dentro de Windows.

La opción recomendada si Claude Code se ejecuta directamente en Windows es **Git Bash**.

### Opción A: Claude Code en Windows con Git Bash

1. Instale [Git for Windows](https://git-scm.com/download/win).
2. Instale `uv` desde PowerShell:

   ```powershell
   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
   ```

   Cierre y vuelva a abrir la terminal. Compruebe que funciona con:

   ```powershell
   uv --version
   ```

3. Abra **Git Bash**. No use PowerShell para ejecutar el instalador.
4. Ejecute:

   ```bash
   git clone https://github.com/latadeloco/agent-php2shell.git
   cd agent-php2shell
   ./install.sh --target claude-code --yes
   ```

5. Reinicie Claude Code. El agente quedará instalado en:

   `C:\Users\<su-usuario>\.claude\agents\php2shell.md`

Si Claude Code no encuentra Git Bash, añada esta configuración a su archivo `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe"
  }
}
```

Si Claude Code utiliza PowerShell sin Git Bash, este agente no podrá ejecutar sus scripts. En ese caso, instale Git for Windows o utilice WSL.

### Opción B: Claude Code dentro de WSL 2

1. Instale WSL desde PowerShell:

   ```powershell
   wsl --install -d Ubuntu
   ```

2. Abra la terminal de Ubuntu y ejecute:

   ```bash
   sudo apt update && sudo apt install -y git curl
   curl -LsSf https://astral.sh/uv/install.sh | sh
   git clone https://github.com/latadeloco/agent-php2shell.git
   cd agent-php2shell
   ./install.sh --target claude-code --yes
   ```

3. Ejecute Claude Code **dentro de WSL** para que vea el agente instalado en ese entorno.

## macOS y Linux

1. Instale `uv`:

   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. Cierre y vuelva a abrir la terminal. Compruebe que funciona:

   ```bash
   uv --version
   ```

3. Clone el repositorio y ejecute el instalador:

   ```bash
   git clone https://github.com/latadeloco/agent-php2shell.git
   cd agent-php2shell
   ./install.sh --dry-run
   ./install.sh --target claude-code --yes
   ```

El modo `--dry-run` muestra lo que se va a instalar sin escribir nada.

## Instalar para otras herramientas

El instalador puede preparar el agente para varias herramientas:

```bash
./install.sh --target opencode
./install.sh --target codex
./install.sh --target gemini
./install.sh --target all
```

También puede instalar el agente solo en el proyecto actual, en lugar de para todo el usuario:

```bash
./install.sh --target claude-code --project
```

## Opciones del instalador

| Opción | Para qué sirve |
|---|---|
| `--target` | Elige la herramienta: `opencode`, `claude-code`, `codex`, `gemini`, `generic`, `auto` o `all`. |
| `--project` | Instala en el proyecto actual en lugar de para todo el usuario. |
| `--model` | Fija un modelo de inteligencia artificial concreto. Si no se indica, se usa el modelo configurado en cada herramienta. |
| `--dry-run` | Muestra el plan sin escribir nada. |
| `--yes` | No pide confirmación. Es necesario cuando el instalador se ejecuta desde Claude Code u otro entorno no interactivo. |
| `--force` | Sobrescribe sin guardar una copia de seguridad. |

## Qué se instala y dónde

El instalador crea tres zonas:

- **Programas:** `~/.local/share/php2shell-agent/`
  Contiene el escáner, el script de triaje y los comandos internos.
- **Informes:** `~/.local/state/php2shell-scans/`
  Aquí se guardan los resultados de los escaneos y del triaje.
- **Agente:** según la herramienta elegida.
  - opencode: `~/.config/opencode/agents/php2shell.md`
  - Claude Code: `~/.claude/agents/php2shell.md`
  - Codex: `~/.codex/agents/php2shell.toml`
  - Gemini: `~/.gemini/commands/php2shell.toml`
  - Genérico: `AGENTS.md` del proyecto

El instalador guarda una copia del agente anterior antes de sobrescribirlo.

## Cómo saber si se ha instalado bien

Ejecute:

```bash
~/.local/share/php2shell-agent/tools/preflight.sh --check
```

Debe terminar con el mensaje `Todo listo.`. Si aparece un error, consulte [Problemas frecuentes](Problemas-frecuentes).

Para opencode, compruebe que aparece:

```bash
opencode agent list
```

Para Claude Code, reinicie la aplicación y abra el menú de agentes o subagentes.

## Desinstalación

```bash
cd agent-php2shell
./uninstall.sh
```

Esto elimina el agente y los comandos internos, pero conserva el escáner, el triaje y los informes. Si desea borrarlo todo:

```bash
./uninstall.sh --purge
```

## Siguiente paso

Cuando termine la instalación, consulte [Uso](Uso) para aprender a pedir la primera revisión.
