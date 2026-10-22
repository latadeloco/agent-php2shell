# Comandos y permisos

Este documento es el contrato de comandos del agente. Los wrappers son iguales para todas las herramientas; solo cambia el adaptador del prompt.

## Herramientas

| Herramienta | Para qué | Comando | Escribe | Red | Permiso |
|---|---|---|---|---|---|
| `preflight` | Revisar herramientas, hashes y permisos | `preflight.sh --check` | No | No | allow |
| `scan` | Escaneo activo | `php2shell-scan.sh --i-have-permission -u <URL>` | Sí (JSON) | Sí | ask |
| `scan --dry-run` | Revisar el comando | `php2shell-scan.sh --dry-run -u <URL>` | No | No | ask |
| `triage` | Triaje de solo lectura | `php2shell-triage.sh <ruta>` | Sí (TXT) | No | ask |
| `curl` | Leer cabeceras | `curl -sS -D - -o /dev/null --max-time 20 ...` | No | Sí | allow |
| `php -v` | Versión local | `php -v` | No | No | allow |
| `date` | Nombre del informe | `date -u +%Y%m%dT%H%M%SZ` | No | No | allow |
| `sha256sum` | Verificar scripts (Linux) | `sha256sum <DATA_DIR>/*` | No | No | allow |
| `shasum` | Verificar scripts (macOS) | `shasum -a 256 <DATA_DIR>/*` | No | No | allow |
| `sudo` | Triaje completo | `sudo bash <VENDOR_DIR>/php2shell-triage.sh <ruta>` | Sí | No | **manual, nunca por el agente** |

## Permisos de opencode

```yaml
edit: deny
webfetch: deny
question: allow
shell:
  "*": deny
  "<TOOLS_DIR>/preflight.sh*": allow
  "<TOOLS_DIR>/php2shell-scan.sh*": ask
  "<TOOLS_DIR>/php2shell-triage.sh*": ask
  "curl -sS -D - -o /dev/null --max-time *": allow
  "php -v": allow
  "date -u +%Y%m%dT%H%M%SZ": allow
  "sha256sum <DATA_DIR>/*": allow
  "shasum -a 256 <DATA_DIR>/*": allow
```

## Permisos de Claude Code

```yaml
tools: Bash, Read, Glob, Grep
permissionMode: default
```

Sin `Write`, sin `Edit` y sin `WebFetch`. Las confirmaciones se piden en texto porque los subagentes no pueden usar `AskUserQuestion`.

## Codex CLI

Archivo TOML en `~/.codex/agents/php2shell.toml` (global) o `.codex/agents/php2shell.toml` (proyecto).

```toml
name = "php2shell"
description = "..."
developer_instructions = "..."
```

Hereda el modelo, el sandbox y las aprobaciones de Codex. Si se pasa `--model`, el instalador añade `model = "..."` al TOML. El agente se invoca pidiendo el subagente `php2shell` por su nombre.

## Gemini CLI

Archivo `~/.gemini/commands/php2shell.toml` (global) o `.gemini/commands/php2shell.toml` (proyecto). Es un comando/prompt; Gemini confirma la ejecución de shell. `--model` no se aplica a este target.

## Códigos de salida

| Código | Significado |
|---|---|
| 0 | Todo correcto o veredicto sin vulnerabilidad |
| 1 | Vulnerable (scanner) o falta una dependencia (preflight) |
| 2 | Error de integridad/permisos o fallo al guardar el informe |
| 3 | El wrapper de escaneo no recibió `--i-have-permission` |

## Flujo de seguridad

1. `preflight --check`
2. Confirmación del usuario
3. `scan --dry-run`
4. Confirmación del usuario
5. `scan --i-have-permission`
6. Informe
7. Oferta de triaje
8. `triage`
