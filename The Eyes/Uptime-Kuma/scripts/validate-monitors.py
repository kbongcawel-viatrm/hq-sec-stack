#!/usr/bin/env python3
"""Validate the Uptime Kuma monitor targets for hq-sec-stack."""

from __future__ import annotations

import importlib
import json
import os
import ssl
import subprocess
import sys
import time
import socket
import urllib.error
import urllib.request
from pathlib import Path


MONITORS_PATH = Path("/uptime-kuma/monitors.yml")
TIMEOUT_SECONDS = int(os.environ.get("SECSTACK_MONITOR_VALIDATE_TIMEOUT_SECONDS", "900"))
RETRY_INTERVAL_SECONDS = int(os.environ.get("SECSTACK_MONITOR_VALIDATE_INTERVAL_SECONDS", "15"))
REQUEST_TIMEOUT_SECONDS = int(os.environ.get("SECSTACK_MONITOR_VALIDATE_REQUEST_TIMEOUT_SECONDS", "15"))


def ensure_yaml() -> object:
    try:
        return importlib.import_module("yaml")
    except ModuleNotFoundError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--no-cache-dir", "PyYAML"])
        return importlib.import_module("yaml")


def parse_accepted_statuscodes(values: object) -> list[tuple[int, int]]:
    if not values:
        return [(200, 299)]

    items = [values] if isinstance(values, (str, int)) else list(values)
    ranges: list[tuple[int, int]] = []
    for item in items:
        text = str(item).strip()
        if "-" in text:
            left, right = text.split("-", 1)
            ranges.append((int(left), int(right)))
        else:
            code = int(text)
            ranges.append((code, code))
    return ranges


def status_allowed(status: int, accepted: list[tuple[int, int]]) -> bool:
    return any(start <= status <= end for start, end in accepted)


def fetch_http(url: str, ignore_tls: bool) -> tuple[int, bytes]:
    context = ssl._create_unverified_context() if ignore_tls else None
    request = urllib.request.Request(url, headers={"User-Agent": "hq-sec-stack-monitor-validator"})
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS, context=context) as response:
        return response.status, response.read()


def runtime_http_target(monitor: dict) -> str:
    endpoint = str(monitor.get("endpoint", "")).strip()
    if endpoint.startswith(("http://", "https://")):
        return endpoint
    return monitor["url"]


def check_http_monitor(monitor: dict) -> tuple[bool, str]:
    url = runtime_http_target(monitor)
    accepted = parse_accepted_statuscodes(monitor.get("accepted_statuscodes"))
    status, body = fetch_http(url, bool(monitor.get("ignore_tls")))

    if "container-health-exporter:8080/container/" in url:
        payload = json.loads(body.decode("utf-8"))
        if status == 200 and payload.get("ok") is True:
            return True, f"{monitor['name']}: ok"
        return False, f"{monitor['name']}: {payload}"

    if status_allowed(status, accepted):
        return True, f"{monitor['name']}: HTTP {status}"

    return False, f"{monitor['name']}: HTTP {status} not in {accepted}"


def check_port_monitor(monitor: dict) -> tuple[bool, str]:
    host = monitor["host"]
    port = int(monitor["port"])
    endpoint = str(monitor.get("endpoint", "")).lower()

    if endpoint.endswith("/udp"):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(REQUEST_TIMEOUT_SECONDS)
            sock.connect((host, port))
            sock.send(b"\0")
        return True, f"{monitor['name']}: UDP probe sent to {host}:{port}"

    with socket.create_connection((host, port), timeout=REQUEST_TIMEOUT_SECONDS):
        return True, f"{monitor['name']}: TCP reachable at {host}:{port}"


def load_monitors() -> list[dict]:
    yaml = ensure_yaml()
    data = yaml.safe_load(MONITORS_PATH.read_text(encoding="utf-8"))
    return list(data.get("monitors", []))


def main() -> int:
    monitors = load_monitors()
    deadline = time.time() + TIMEOUT_SECONDS

    http_monitors = [monitor for monitor in monitors if monitor.get("type") == "http"]
    port_monitors = [monitor for monitor in monitors if monitor.get("type") == "port"]
    skipped = [monitor["name"] for monitor in monitors if monitor.get("type") not in {"http", "port"}]

    while True:
        failures: list[str] = []
        for monitor in http_monitors:
            try:
                ok, message = check_http_monitor(monitor)
            except Exception as exc:
                ok = False
                message = f"{monitor['name']}: {exc}"
            print(message)
            if not ok:
                failures.append(message)

        for monitor in port_monitors:
            try:
                ok, message = check_port_monitor(monitor)
            except Exception as exc:
                ok = False
                message = f"{monitor['name']}: {exc}"
            print(message)
            if not ok:
                failures.append(message)

        if not failures:
            print(
                f"Validated {len(http_monitors)} HTTP monitors and {len(port_monitors)} port monitors successfully."
            )
            if skipped:
                print(f"Skipped {len(skipped)} non-HTTP monitors: {', '.join(skipped)}")
            return 0

        if time.time() >= deadline:
            print("Monitor validation failed after retries.")
            print("\n".join(failures))
            return 1

        print(f"{len(failures)} monitors still failing; retrying in {RETRY_INTERVAL_SECONDS}s.")
        time.sleep(RETRY_INTERVAL_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
