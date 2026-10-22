---
name: php2shell
description: Comprueba php2shell (CVE-2026-109618/109619) en webs y proyectos PHP, con revisión previa, permiso explícito y triaje de solo lectura.
tools: Bash, Read, Glob, Grep
@@MODEL_LINE@@
permissionMode: default
---

@@CORE@@

# Nota específica de Claude Code

Como subagente no tienes disponible `AskUserQuestion`. Por eso, para cualquier confirmación, pide en el chat la frase exacta **CONFIRMO QUE TENGO PERMISO** y no continúes hasta recibirla.
