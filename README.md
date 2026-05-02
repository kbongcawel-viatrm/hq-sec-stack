<img width="1918" height="724" alt="IMG_0015" src="https://github.com/user-attachments/assets/170ed071-d6de-4dd4-b14e-f11aff66c2cc" />

# HQ Security Stack

A comprehensive home security stack aimed at implementing file integrity monitoring, alerting, intrusion prevention/detection systems, log assessment and forensics, log aggregation visualization, and response mitigation.

## Quick Start

```bash
cp .env.example .env
sh scripts/start-stack.sh
```

To gracefully stop everything:
```bash
sh scripts/killswitch.sh
```

## Available Profiles

You can run specific components by passing profiles to the startup script:
```bash
SECSTACK_PROFILES="dns secrets brain" sh scripts/start-stack.sh
```

- `all`: Full lab stack
- `brain`: SIEM and log analysis (Wazuh, Graylog)
- `network`: Network detection (Suricata, Zeek, Nmap, Wireshark)
- `ir`: Incident response (TheHive, Shuffle, Velociraptor)
- `vuln`: Vulnerability and hardening (Greenbone, osquery)
- `dns`: Local FQDN routing (CoreDNS, Caddy)
- `secrets`: Secrets storage and rotation (Vault)
- `ops`: Backups and container vulnerability scanning
- `dashboard`: Local reports and AI assessment

## Key Endpoints

| Service | Host Endpoint |
| --- | --- |
| Wazuh Dashboard | `https://localhost:5601` |
| Graylog | `http://localhost:9000` |
| Portainer | `https://localhost:9443` |
| Uptime Kuma | `http://localhost:3002` |
| Vault | `http://localhost:8200` |
| CrowdSec | `http://localhost:8080` |

## Security & Privacy Features

- **Private Binding**: All services are bound to `127.0.0.1` by default to prevent external network exposure.
- **DNS over TLS**: Internal DNS resolution via CoreDNS uses encrypted DoT to Quad9 (`dns.quad9.net`) to prevent ISP tracking.
- **Active IPS**: CrowdSec monitors Wazuh, Suricata, and Caddy logs, and actively blocks malicious IPs using the Caddy bouncer plugin.

## Important Safety Notes

This is a lab stack. Replace all default passwords and secrets in your `.env` before using it beyond a private test environment. 

Some containers require privileged access:
- Suricata, Zeek, and Wireshark require host networking and packet-capture capabilities.
- Portainer and Shuffle mount `/var/run/docker.sock` to manage the environment.
- Greenbone scanner requires network scanning capabilities.

**Do not run vulnerability scans, containment playbooks, or endpoint collection against systems without authorization.**
