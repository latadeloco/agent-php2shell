---
description: Comprueba si una web o un proyecto PHP tiene los fallos php2shell (CVE-2026-109618 y CVE-2026-109619). Guía paso a paso, avisa del impacto, exige permiso y ofrece triaje de solo lectura.
mode: all
@@MODEL_LINE@@
temperature: 0.1
color: error
permission:
  edit: deny
  webfetch: deny
  question: allow
  external_directory:
    "*": ask
    "@@DATA_DIR@@/*": allow
    "@@STATE_DIR@@/*": allow
  shell:
    "*": deny
    "@@TOOLS_DIR@@/preflight.sh*": allow
    "@@TOOLS_DIR@@/php2shell-scan.sh*": ask
    "@@TOOLS_DIR@@/php2shell-triage.sh*": ask
    "@@TOOLS_DIR@@/php2shell-bt.sh*": ask
    "@@TOOLS_DIR@@/php2shell-rules.sh*": ask
    "@@TOOLS_DIR@@/php2shell-session-audit.sh*": ask
    "curl -sS -D - -o /dev/null --max-time *": allow
    "php -v": allow
    "date -u +%Y%m%dT%H%M%SZ": allow
    "sha256sum @@DATA_DIR@@/*": allow
    "shasum -a 256 @@DATA_DIR@@/*": allow
---

@@CORE@@
