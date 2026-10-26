#!/usr/bin/env python3
"""Static www/ + POST /api/session → prax-web-session (JSON-lines)."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WWW = ROOT / "www"
HOST = "127.0.0.1"
PORT = int(os.environ.get("PORT", "8080"))
REPO = ROOT.parent


def find_bridge() -> Path | None:
    env = os.environ.get("PRAX_WEB_SESSION")
    if env:
        p = Path(env)
        if p.is_file():
            return p
    which = shutil.which("prax-web-session")
    if which:
        return Path(which)
    for base in (REPO / ".stack-work" / "install", Path.home() / ".local" / "bin"):
        if not base.exists():
            continue
        for p in base.rglob("prax-web-session"):
            if p.is_file() and os.access(p, os.X_OK):
                return p
    return None


class SessionBridge:
    def __init__(self, binary: Path) -> None:
        self._lock = threading.Lock()
        self._proc = subprocess.Popen(
            [str(binary)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )

    def call(self, payload: dict) -> dict:
        line = json.dumps(payload, ensure_ascii=False)
        with self._lock:
            if self._proc.poll() is not None:
                err = self._proc.stderr.read() if self._proc.stderr else ""
                return {"ok": False, "error": "bridge_dead", "message": err or "exited"}
            assert self._proc.stdin and self._proc.stdout
            self._proc.stdin.write(line + "\n")
")
            self._proc.stdin.flush()
            out = self._proc.stdout.readline()
            if not out:
                err = self._proc.stderr.read() if self._proc.stderr else ""
                return {"ok": False, "error": "bridge_eof", "message": err or "no response"}
            try:
                return json.loads(out)
            except json.JSONDecodeError as e:
                return {"ok": False, "error": "bad_json", "message": str(e), "raw": out[:500]}

    def close(self) -> None:
        if self._proc.poll() is None:
            self._proc.terminate()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, bridge: SessionBridge | None = None, **kwargs):
        self.bridge = bridge
        super().__init__(*args, directory=str(WWW), **kwargs)

    def do_POST(self) -> None:  # noqa: N802
        if self.path.split("?", 1)[0] != "/api/session":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError as e:
            self._json(400, {"ok": False, "error": "bad_request", "message": str(e)})
            return
        if self.bridge is None:
            self._json(
                503,
                {
                    "ok": False,
                    "error": "no_bridge",
                    "message": "未找到 prax-web-session；请先 stack build prax:exe:prax-web-session",
                },
            )
            return
        result = self.bridge.call(payload if isinstance(payload, dict) else {})
        self._json(200 if result.get("ok") else 400, result)

    def _json(self, status: int, body: dict) -> None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))
" % (self.address_string(), fmt % args))


def main() -> int:
    if not WWW.is_dir():
        print(f"missing {WWW}", file=sys.stderr)
        return 1
    binary = find_bridge()
    bridge = SessionBridge(binary) if binary else None
    if binary:
        print(f"Session bridge: {binary}")
    else:
        print("WARNING: prax-web-session not found; /api/session will 503", file=sys.stderr)
    handler = partial(Handler, bridge=bridge)
    httpd = ThreadingHTTPServer((HOST, PORT), handler)
    print(f"Serving {WWW} at http://{HOST}:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("
bye")
    finally:
        if bridge:
            bridge.close()
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
