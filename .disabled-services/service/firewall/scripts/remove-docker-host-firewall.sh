#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root so iptables can update DOCKER-USER." >&2
  exit 1
fi

iptables -D DOCKER-USER -j HQ_SEC_STACK 2>/dev/null || true
iptables -F HQ_SEC_STACK 2>/dev/null || true
iptables -X HQ_SEC_STACK 2>/dev/null || true
echo "Removed hq-sec-stack DOCKER-USER allowlist."
