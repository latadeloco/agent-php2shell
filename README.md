# php2shell-agent

Agente de seguridad para comprobar si una web o un proyecto PHP es vulnerable a php2shell (**CVE-2026-109618** y **CVE-2026-109619**) y para buscar señales de que el fallo ya se haya aprovechado. Se instala sobre **opencode, Claude Code, Codex CLI, Gemini CLI** o cualquier herramienta compatible con `AGENTS.md`.

Usa el scanner oficial de **Assetnote** y un script de triaje de solo lectura de **Sairahcaz**. Incluye revisión previa de herramientas y permisos, avisos de impacto y confirmación explícita antes de lanzar pruebas activas. No redistribuye el código de terceros: lo descarga con versión fijada y verifica su hash.

> **Aviso importante:** la prueba completa es activa y **puede tumbar el servidor**. Envía hasta unos 29 MB y puede dejar PHP-FPM/mod_php caído unos segundos. Úsala solo en servidores propios o con autorización por escrito, preferiblemente en staging o en una ventana de mantenimiento. El agente exige `--i-have-permission` y ofrece un `--dry-run` para revisar el comando antes.

## Documentación

La guía completa para usuario final está en la wiki:

https://github.com/latadeloco/agent-php2shell/wiki

El contenido fuente está en [`wiki/`](wiki/) y se publica con:

```bash
./scripts/publish-wiki.sh
```

## Qué hace

1. **Revisión previa:** comprueba herramientas, versiones, hashes y permisos antes de ejecutar nada.
2. **Prueba rápida:** lee `X-Powered-By` y compara la versión de PHP con las versiones parcheadas.
3. **Prueba activa:** ejecuta el scanner de Assetnote contra un único objetivo, con un hilo y timeout controlado.
4. **Triaje:** si el resultado es `VULNERABLE` o se solicita, busca señales de compromiso en el equipo (solo lectura).
5. **Informe:** resumen en lenguaje claro, recomendaciones y anexo técnico.

Versiones que corrigen el fallo:

| Rama | Versión parcheada |
|------|-------------------|
| PHP 8.2 | 8.2.35 |
| PHP 8.3 | 8.3.36 |
| PHP 8.4 | 8.4.27 |
| PHP 8.5 | 8.5.12 |

## Herramientas soportadas

| Herramienta | Instalación | Invocación |
|---|---|---|
| opencode | `~/.config/opencode/agents/php2shell.md` | Tab o `@php2shell` |
| Claude Code | `~/.claude/agents/php2shell.md` | subagente `php2shell` |
| Codex CLI | `~/.codex/agents/php2shell.toml` | subagente `php2shell` |
| Gemini CLI | `~/.gemini/commands/php2shell.toml` | `/php2shell` |
| Genérico | `AGENTS.md` del proyecto | según la herramienta |

En Claude Code, los subagentes no pueden usar `AskUserQuestion`; por eso el agente pide la frase exacta **CONFIRMO QUE TENGO PERMISO** cuando no hay herramienta de pregunta estructurada.

## Requisitos

- Linux, macOS, WSL o **Windows nativo con Git for Windows (Git Bash)**.
- `bash`, `git`, `curl`, `sha256sum` (Linux/Windows) o `shasum` (macOS).
- [`uv`](https://docs.astral.sh/uv/) para ejecutar el scanner y sus dependencias.
- Opcional: `php` para revisar proyectos locales.
- Opcional: `opencode`, `claude`, `codex` o `gemini` según el destino.

En Windows nativo, **Git for Windows es obligatorio**: Claude Code usa Git Bash para ejecutar los wrappers. Sin Git Bash, Claude Code usa PowerShell y este agente no puede ejecutar los scripts `.sh`.

## Instalación

```bash
git clone https://github.com/latadeloco/agent-php2shell.git php2shell-agent
cd php2shell-agent
./install.sh --dry-run     # revisa el plan sin escribir nada
./install.sh               # instala en las herramientas detectadas
```

Opciones:

```bash
./install.sh --target opencode
./install.sh --target all
./install.sh --target claude-code --project
./install.sh --target opencode --model deepseek/deepseek-flash
./install.sh --target all --yes
```

- `--target auto` detecta `opencode`, `claude`, `codex` y `gemini`. Si no encuentra ninguna, instala el bloque genérico.
- `--project` instala en el proyecto actual (`.opencode/`, `.claude/`, `.gemini/` o `AGENTS.md`).
- `--model` es opcional. Sin él, el agente hereda el modelo configurado en cada herramienta. Se aplica a opencode, Claude Code y Codex; Gemini usa el modelo configurado en su CLI.
- `--dry-run` muestra el plan y no escribe.
- `--force` sobrescribe sin backup.

### Instalar desde Claude Code

> **Cuidado:** el agente ejecuta una prueba activa que puede tumbar PHP-FPM/mod_php. No lo instales ni lo lances contra producción sin autorización y sin una ventana de mantenimiento.

Si le pides a Claude Code que instale el agente, dile que ejecute:

```bash
git clone https://github.com/latadeloco/agent-php2shell.git
cd agent-php2shell
./install.sh --target claude-code --yes
```

O pega directamente este prompt en Claude Code:

```text
Instala php2shell-agent desde https://github.com/latadeloco/agent-php2shell:
clona el repo, ejecuta ./install.sh --target claude-code --yes y reinicia Claude Code.
Aviso: hace pruebas activas que pueden tumbar el servidor; solo debe usarse con autorización.
```

Claude pedirá permiso para ejecutar los comandos. Al terminar, **reinicia Claude Code** si la carpeta `~/.claude/agents/` no existía antes, para que detecte el subagente.

Si `uv` no está instalado, el instalador se detendrá y mostrará el comando para instalarlo.

El instalador ejecuta un preflight, muestra qué va a crear y pide confirmación antes de tocar nada.

### Windows

#### Opción A: Claude Code nativo con Git Bash (recomendada)

1. Instala [Git for Windows](https://git-scm.com/download/win). Incluye Git Bash.
2. Instala `uv` desde PowerShell:

   ```powershell
   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
   ```

   Cierra y vuelve a abrir la terminal. Comprueba con `uv --version`.
3. Abre **Git Bash** (no PowerShell) y ejecuta:

   ```bash
   git clone https://github.com/latadeloco/agent-php2shell.git
   cd agent-php2shell
   ./install.sh --target claude-code --yes
   ```

4. Reinicia Claude Code. El agente queda en `C:\Users\<tu-usuario>\.claude\agents\php2shell.md`.

Si Claude Code no encuentra Git Bash, añade esto a tu `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe"
  }
}
```

> **Aviso:** la prueba activa puede tumbar PHP-FPM/mod_php. En Windows, úsala solo contra servidores de pruebas o con autorización.

#### Opción B: WSL2

Si prefieres Linux, instala WSL2 y ejecuta Claude Code **dentro de WSL**:

```powershell
wsl --install -d Ubuntu
```

Después, en la terminal de Ubuntu:

```bash
sudo apt update && sudo apt install -y git curl
curl -LsSf https://astral.sh/uv/install.sh | sh
git clone https://github.com/latadeloco/agent-php2shell.git
cd agent-php2shell
./install.sh --target claude-code --yes
```

El agente se instala en el `~/.claude/agents/` de WSL. Claude Code debe ejecutarse también dentro de WSL para verlo. Si Claude Code es nativo de Windows, usa la Opción A.

Si Claude Code usa PowerShell sin Git Bash, este agente no puede ejecutar los wrappers `.sh`. En ese caso instala Git for Windows o usa WSL2.

> **Triaje en Windows:** no hay `sudo` ni logs de PHP-FPM en `/var/log`; el triaje verá menos información que en Linux. La prueba rápida y el escaneo funcionan igual.

## Uso

Pide al agente que revise una URL o un proyecto:

```text
Revisa si https://mi-web.example tiene php2shell
```

El flujo es siempre:

1. Preflight y tabla de herramientas.
2. Prueba rápida de versión.
3. Aviso y confirmación.
4. `--dry-run` del escaneo activo.
5. Escaneo con `--i-have-permission`.
6. Informe y, si aplica, oferta de triaje.

### Modo breve

Por defecto el agente responde en **10–12 líneas** y no repite la salida de las herramientas. Los informes guardados contienen toda la información. Si necesita el detalle completo, pida **“detalle”**, **“explica más”** o **“informe completo”**.

### Uso manual de los wrappers

```bash
# Revisión previa resumida
~/.local/share/php2shell-agent/tools/preflight.sh --brief

# Revisión previa completa, si necesita el detalle
~/.local/share/php2shell-agent/tools/preflight.sh --check

# Ver el comando exacto sin enviar tráfico
~/.local/share/php2shell-agent/tools/php2shell-scan.sh --dry-run -u https://example.com

# Escaneo real (solo con autorización)
~/.local/share/php2shell-agent/tools/php2shell-scan.sh \
  --i-have-permission -u https://example.com --timeout 90 -t 1 --all-results

# Triaje de solo lectura, con resumen
~/.local/share/php2shell-agent/tools/php2shell-triage.sh --summary /ruta/al/proyecto

# Triaje completo, si necesita el detalle
~/.local/share/php2shell-agent/tools/php2shell-triage.sh /ruta/al/proyecto
```

Los informes se guardan en `~/.local/state/php2shell-scans/`.

## Estructura

```text
php2shell-agent/
├── core/prompt.md              # comportamiento común
├── adapters/                   # opencode, Claude Code, Codex, Gemini, genérico
├── scripts/
│   ├── php2shell-preflight.sh
│   ├── php2shell-scan.sh
│   ├── php2shell-triage.sh
│   └── lib.sh
├── docs/COMMANDS.md
├── tests/
├── install.sh
├── uninstall.sh
└── verify.sh
```

## Seguridad

- Sin `--i-have-permission`, el wrapper de escaneo se niega a ejecutar (código 3).
- `--dry-run` permite revisar el comando sin abrir conexión al objetivo.
- El agente no edita archivos, no navega por su cuenta y no ejecuta `sudo`.
- El triaje es de solo lectura y no borra malware ni "limpia" el servidor.
- Los informes pueden contener IPs, rutas y datos internos. No los publiques.

Más detalles en [SECURITY.md](SECURITY.md) y en [docs/COMMANDS.md](docs/COMMANDS.md).

## Fuentes y créditos

- Scanner: [assetnote/php2shell-scanner](https://github.com/assetnote/php2shell-scanner), commit `353545fe…`.
- Triaje: [gist de Sairahcaz](https://gist.github.com/Sairahcaz/2c22b4a68fd5b75e410c7f9f69f485a0), revisión `ec40176…`.
- Descubrimiento original: [equipo Calif](https://calif.io/php2shell/).

Sin afiliación ni respaldo de Assetnote, Sairahcaz ni Calif. Ver [SOURCES.md](SOURCES.md).

## Licencia

El código de este repositorio se publica bajo licencia MIT. El scanner de Assetnote y el gist de Sairahcaz no incluyen licencia y **no se redistribuyen**; el instalador los descarga desde su origen con versión fijada y hash verificado. Consulta [SOURCES.md](SOURCES.md).

## Desarrollo

```bash
./verify.sh
```

Ejecuta comprobaciones de sintaxis, tests de render, preflight y pruebas del bloqueo de seguridad. No lanza escaneos activos.

## Desinstalación

```bash
./uninstall.sh
./uninstall.sh --purge   # borra también scanner, triaje e informes
```
