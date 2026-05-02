# IPFire Green/Red Edge Firewall Design

IPFire is an open-source firewall distribution designed to run as a VM or bare-metal gateway, not as a normal Docker sidecar. Use IPFire as the first line of defense in front of the Docker host.

## Topology

```text
Internet / upstream LAN
        |
      RED
   IPFire VM
      GREEN: 10.77.0.1/24
        |
Docker host GREEN IP: 10.77.0.10/24
        |
hq-sec-stack secnet: 10.77.0.0/24
FQDN proxy /32 target: 10.77.0.80/32
```

Use Green and Red only:

- RED: untrusted upstream/WAN.
- GREEN: trusted service network.
- No Blue or Orange zones.

## Required IPFire Rules

Default inbound policy from RED to GREEN: block/drop all inbound connections.

Allow only these inbound RED -> GREEN services to the Docker host or FQDN proxy. Treat all other inbound traffic as dropped.

| Class | Source | Destination | Protocol | Port | Purpose |
| --- | --- | --- | --- | --- | --- |
| Public | Approved RED sources | `${STACK_HOST_GREEN_IP}` or `10.77.0.80` | TCP | `80` | FQDN reverse proxy |
| Endpoint ingest | Endpoint networks | `${STACK_HOST_GREEN_IP}` | UDP | `1514` | Wazuh agent events |
| Endpoint ingest | Endpoint networks | `${STACK_HOST_GREEN_IP}` | TCP | `1515` | Wazuh agent enrollment |
| Endpoint ingest | Endpoint networks | `${STACK_HOST_GREEN_IP}` | UDP | `12201` | Graylog GELF |
| Endpoint ingest | Endpoint networks | `${STACK_HOST_GREEN_IP}` | TCP/UDP | `5514` | Graylog syslog |
| Endpoint ingest | Endpoint networks | `${STACK_HOST_GREEN_IP}` | TCP | `8000` | Velociraptor client frontend |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `3001` | Shuffle frontend |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `3002` | Uptime Kuma |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `5001` | Shuffle backend |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `55000` | Wazuh API |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `5601` | Wazuh Dashboard |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `8200` | Vault |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `8889` | Velociraptor GUI |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `9000` | Graylog direct UI |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `9001` | TheHive direct UI |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `9200` | Wazuh Indexer |
| Admin only | Admin workstation/VPN CIDRs | `${STACK_HOST_GREEN_IP}` | TCP | `9392`, `9443` | Greenbone |

Do not expose raw internal Docker service ports directly from RED unless listed above. If a port is not in this table and not in `firewall/allowed-ports.env`, it must remain blocked.

## Docker Host Enforcement

Run `firewall/scripts/apply-docker-host-firewall.sh` on the Docker host. It inserts allowlist rules into the Docker `DOCKER-USER` chain so undefined inbound ports are blocked even if a container publishes a port.

This complements IPFire. IPFire blocks at the network edge; the host rules block accidental Docker exposure on the service host.

The host allowlist permits egress from `INTERNAL_CIDRS` so containers can reach updates, feeds, and upstream APIs. Inbound traffic is default-drop and remains limited to the public, endpoint, admin, and DNS classes in `firewall/allowed-ports.env`.

## Suricata Placement Decision

IPFire can provide IDS/IPS at the Green/Red boundary. The separate `suricata` container is not a replacement for IPFire; it is a SOC sensor.

Recommended default: keep both only when each sees different traffic.

- Keep IPFire IDS/IPS for north-south edge traffic between RED and GREEN.
- Keep the Suricata container only if `${SENSOR_INTERFACE}` receives mirrored/SPAN/TAP traffic from the Docker host, service VLAN, or endpoint network.
- Disable the Suricata container profile if it only sees the same Green/Red traffic as IPFire or if no mirrored interface exists.

Decision matrix:

| Condition | Keep IPFire IDS/IPS | Keep Suricata container |
| --- | --- | --- |
| Need edge blocking/prevention | Yes | No, not for blocking |
| Need SOC-visible IDS logs in Graylog | Yes, forward IPFire logs if available | Yes, if sensor interface sees useful traffic |
| Only one capture point available at the edge | Yes | No |
| Need east-west/internal Docker or endpoint visibility | No | Yes, with SPAN/TAP/mirror |
| Low-resource lab host | Yes | Optional/off |
