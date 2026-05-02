#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
ALLOW_FILE="${ALLOW_FILE:-${ROOT_DIR}/firewall/allowed-ports.env}"
CHAIN="HQ_SEC_STACK"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root so iptables can update DOCKER-USER." >&2
  exit 1
fi

. "${ALLOW_FILE}"

iptables -N "${CHAIN}" 2>/dev/null || true
iptables -F "${CHAIN}"
iptables -C DOCKER-USER -j "${CHAIN}" 2>/dev/null || iptables -I DOCKER-USER 1 -j "${CHAIN}"

# Default inbound stance: drop. The RETURN rules below are explicit exceptions.
iptables -A "${CHAIN}" -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
iptables -A "${CHAIN}" -i lo -j RETURN

for cidr in ${INTERNAL_CIDRS:-}; do
  iptables -A "${CHAIN}" -s "${cidr}" -j RETURN
done

allow_any() {
  proto="$1"
  ports="$2"
  for port in ${ports:-}; do
    iptables -A "${CHAIN}" -p "${proto}" --dport "${port}" -j RETURN
  done
}

allow_from_cidrs() {
  proto="$1"
  ports="$2"
  cidrs="$3"
  for cidr in ${cidrs:-}; do
    for port in ${ports:-}; do
      iptables -A "${CHAIN}" -p "${proto}" -s "${cidr}" --dport "${port}" -j RETURN
    done
  done
}

allow_any tcp "${PUBLIC_TCP_PORTS:-}"
allow_any udp "${PUBLIC_UDP_PORTS:-}"

allow_from_cidrs tcp "${ENDPOINT_TCP_PORTS:-}" "${ENDPOINT_CIDRS:-}"
allow_from_cidrs udp "${ENDPOINT_UDP_PORTS:-}" "${ENDPOINT_CIDRS:-}"

allow_from_cidrs tcp "${ADMIN_TCP_PORTS:-}" "${ADMIN_CIDRS:-}"
allow_from_cidrs udp "${ADMIN_UDP_PORTS:-}" "${ADMIN_CIDRS:-}"

allow_from_cidrs tcp "${DNS_TCP_PORTS:-}" "${DNS_CIDRS:-}"
allow_from_cidrs udp "${DNS_UDP_PORTS:-}" "${DNS_CIDRS:-}"

iptables -A "${CHAIN}" -m limit --limit 12/min -j LOG --log-prefix "HQ_SEC_DROP " --log-level 4
iptables -A "${CHAIN}" -j DROP

echo "Applied hq-sec-stack inbound allowlist to DOCKER-USER."
echo "Default inbound policy: DROP unless explicitly allowed."
echo "Public TCP: ${PUBLIC_TCP_PORTS:-none}"
echo "Endpoint CIDRs: ${ENDPOINT_CIDRS:-none}"
echo "Admin CIDRs: ${ADMIN_CIDRS:-none}"
