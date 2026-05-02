#!/usr/bin/env python3
"""Expose Docker container health as simple HTTP endpoints for Uptime Kuma."""

from __future__ import annotations

import http.server
import json
import socket
import urllib.parse


DOCKER_SOCK = "/var/run/docker.sock"


def docker_get(path: str) -> dict:
    request = f"GET {path} HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n\r\n".encode()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(DOCKER_SOCK)
        client.sendall(request)
        chunks = []
        while True:
            chunk = client.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
    raw = b"".join(chunks)
    header, _, body = raw.partition(b"\r\n\r\n")
    status_line = header.splitlines()[0].decode(errors="replace")
    status = int(status_line.split()[1])
    if status >= 400:
        raise RuntimeError(f"Docker API returned {status}")
    return json.loads(body.decode())


def container_ok(name: str, mode: str) -> tuple[bool, dict]:
    info = docker_get(f"/containers/{urllib.parse.quote(name, safe='')}/json")
    state = info.get("State", {})
    running = state.get("Running") is True
    health = state.get("Health", {}).get("Status")
    exit_code = state.get("ExitCode")
    if mode == "completed":
        ok = state.get("Status") == "exited" and exit_code == 0
    else:
        ok = running and health not in {"unhealthy", "starting"}
    return ok, {
        "name": name,
        "running": running,
        "health": health or "none",
        "status": state.get("Status", "unknown"),
        "exit_code": exit_code,
        "mode": mode,
    }


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/healthz":
            self.send_json(200, {"ok": True})
            return

        prefix = "/container/"
        if self.path.startswith(prefix):
            parsed = urllib.parse.urlparse(self.path)
            name = urllib.parse.unquote(parsed.path[len(prefix) :])
            query = urllib.parse.parse_qs(parsed.query)
            mode = query.get("mode", ["running"])[0]
            try:
                ok, payload = container_ok(name, mode)
            except Exception as exc:
                self.send_json(503, {"ok": False, "name": name, "error": str(exc)})
                return
            self.send_json(200 if ok else 503, {"ok": ok, **payload})
            return

        self.send_json(404, {"ok": False, "error": "not found"})

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, sort_keys=True).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"{self.client_address[0]} - {fmt % args}")


if __name__ == "__main__":
    server = http.server.ThreadingHTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()
