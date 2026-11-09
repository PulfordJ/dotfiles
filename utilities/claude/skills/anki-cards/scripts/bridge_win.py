# Runs under *Windows* Python (stdlib only), started by ankiconnect.py from WSL.
# One JSON request per stdin line -> POST to AnkiConnect on Windows' localhost
# -> one JSON response per stdout line. WSL (NAT networking) can't reach
# Windows' 127.0.0.1, but a Windows process can, and pipes need no firewall rule.
import json
import sys
import urllib.request

URL = "http://127.0.0.1:8765"

for line in sys.stdin.buffer:
    req = line.strip()
    if not req:
        continue
    try:
        r = urllib.request.Request(URL, data=req, headers={"Content-Type": "application/json"})
        body = urllib.request.urlopen(r, timeout=900).read()
    except Exception as e:  # noqa: BLE001 - report any failure back to the caller
        body = json.dumps({"result": None, "error": f"AnkiConnect unreachable from Windows ({e!r}) - is Anki open?"}).encode()
    sys.stdout.buffer.write(body.replace(b"\n", b" ") + b"\n")
    sys.stdout.buffer.flush()
