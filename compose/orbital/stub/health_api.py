#!/usr/bin/env python3
"""Stub ServiceHealth API for the Orbital evaluation (stdlib only; GET only; no secrets).

    GET /health   -> [{"svc": "<component id>", "up": true, "checked_at": "<UTC ISO8601>Z"}, ...]
    GET /healthz  -> {"status": "ok"}   (the stub's own liveness)

`svc` names the key differently on purpose (the homelab-arch API calls it `id` / `_id`); the project's
spec for this stub types it homelab.EntityId, which is what lets Orbital join it. The component ids and
their fixed `up` values come from targets.json. Runs as a non-root, read-only container on the compose
network only (see compose.dev.yaml); also usable on beeblebox (Task 6).
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def make_server(addr, targets):
    class Handler(BaseHTTPRequestHandler):
        server_version = "health-stub"

        def _send(self, code, body):
            data = json.dumps(body).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):  # noqa: N802
            path = self.path.split("?", 1)[0]
            if path == "/health":
                self._send(200, [{"svc": t["svc"], "up": bool(t["up"]), "checked_at": _now()} for t in targets])
            elif path == "/healthz":
                self._send(200, {"status": "ok"})
            else:
                self._send(404, {"detail": "not found"})

        def log_message(self, fmt, *args):  # one line per request on stderr
            super().log_message(fmt, *args)

    return ThreadingHTTPServer(addr, Handler)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8110)
    ap.add_argument("--targets", type=Path, default=Path(__file__).with_name("targets.json"))
    a = ap.parse_args(argv)
    targets = json.loads(a.targets.read_text())["targets"]
    make_server((a.host, a.port), targets).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
