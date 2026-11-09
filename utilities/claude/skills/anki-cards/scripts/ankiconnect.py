#!/usr/bin/env python3
"""Minimal AnkiConnect client that works from WSL, macOS and Linux (stdlib only).

Inside WSL, Anki runs on the Windows host and AnkiConnect listens only on
Windows' 127.0.0.1, which WSL's NAT networking can't reach. If a direct
request fails there, requests are relayed through a small Windows-side Python
process (bridge_win.py) over stdin/stdout. On WSL, absolute media paths are
also rewritten to Windows paths so Windows Anki can open them.

As a module:  import ankiconnect; ankiconnect.invoke("deckNames")
As a CLI:     ankiconnect.py <action> ['<json params>' | -]   ("-" reads params from stdin)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.request

URL = os.environ.get("ANKICONNECT_URL", "http://127.0.0.1:8765")
HERE = os.path.dirname(os.path.abspath(__file__))
try:
    IS_WSL = "microsoft" in open("/proc/version").read().lower()
except OSError:
    IS_WSL = False

_transport = None


def _direct(payload: bytes) -> dict:
    req = urllib.request.Request(URL, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.loads(r.read())


def _windows_python() -> str:
    out = subprocess.run(["cmd.exe", "/c", "where python"], capture_output=True, text=True, cwd="/mnt/c").stdout
    for line in out.splitlines():
        p = line.strip()
        if p.lower().endswith("python.exe") and "windowsapps" not in p.lower():
            return subprocess.check_output(["wslpath", "-u", p], text=True).strip()
    raise RuntimeError("No Windows python.exe on PATH; it is needed to reach Anki from WSL.")


class _Bridge:
    def __init__(self) -> None:
        script = subprocess.check_output(["wslpath", "-w", os.path.join(HERE, "bridge_win.py")], text=True).strip()
        self.proc = subprocess.Popen([_windows_python(), "-u", script], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def __call__(self, payload: bytes) -> dict:
        self.proc.stdin.write(payload + b"\n")
        self.proc.stdin.flush()
        line = self.proc.stdout.readline()
        if not line:
            raise RuntimeError("Windows AnkiConnect bridge exited unexpectedly")
        return json.loads(line)


def _pick_transport():
    probe = json.dumps({"action": "version", "version": 6}).encode()
    try:
        urllib.request.urlopen(urllib.request.Request(URL, data=probe, headers={"Content-Type": "application/json"}), timeout=3).read()
        return _direct
    except OSError:
        if not IS_WSL:
            raise RuntimeError(f"Can't reach AnkiConnect at {URL}. Is Anki open with the AnkiConnect add-on?") from None
    return _Bridge()


def _host_path(p):
    """Path as the (possibly Windows) Anki process sees it."""
    if not (IS_WSL and isinstance(p, str) and p.startswith("/")):
        return p
    m = re.match(r"^/mnt/([a-z])/(.*)$", p)
    if m:
        return f"{m.group(1).upper()}:\\" + m.group(2).replace("/", "\\")
    return subprocess.check_output(["wslpath", "-w", p], text=True).strip()


def _translate(action: str, params: dict) -> dict:
    if action == "storeMediaFile" and "path" in params:
        return dict(params, path=_host_path(params["path"]))
    if action == "multi":
        return dict(params, actions=[dict(a, params=_translate(a["action"], a.get("params", {}))) for a in params.get("actions", [])])
    return params


def invoke(action: str, **params):
    """Call an AnkiConnect action; raises RuntimeError with AnkiConnect's error."""
    global _transport
    if _transport is None:
        _transport = _pick_transport()
    payload = json.dumps({"action": action, "version": 6, "params": _translate(action, params)}, ensure_ascii=True).encode()
    resp = _transport(payload)
    if resp.get("error"):
        raise RuntimeError(resp["error"])
    return resp.get("result")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    action = sys.argv[1]
    raw = sys.argv[2] if len(sys.argv) > 2 else "{}"
    params = json.loads(sys.stdin.read() if raw == "-" else raw)
    print(json.dumps(invoke(action, **params), ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
