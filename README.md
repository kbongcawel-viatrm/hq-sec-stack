<img width="1918" height="724" alt="IMG_0015" src="https://github.com/user-attachments/assets/170ed071-d6de-4dd4-b14e-f11aff66c2cc" />


# HQ Security Stack

A comprehensive home security stack aimed at implementing file integrity monitoring (FIM), alerting, intrusion prevention/detection systems (IPS/IDS), log assessment and forensics, log aggregation visualization, and response and mitigation steps for possible malicious attacks.

## Quick Start

```bash
cp .env.example .env
sh scripts/start-stack.sh
```

Docker is expected on the target Linux host. This repository was prepared from Windows, so host-side Docker validation should be run on the deployment host.

The default start script runs the `all` profile. To start a smaller set:

```bash
SECSTACK_PROFILES="dns secrets brain" sh scripts/start-stack.sh
```

Gracefully stop everything without deleting volumes:

```bash
sh scripts/killswitch.sh
```

## Profiles

| Profile | Purpose | Main services |
| --- | --- | --- |
| `dns` | Local FQDN routing | `secdns`, `fqdn-proxy` |
| `secrets` | Secrets storage and rotation | `vault`, `vault-rotator` |
| `ops` | Backups and vulnerability observation | `volume-backup`, `container-vuln-scanner` |
| `logs` | Log input bootstrap and forwarding | `graylog-bootstrap`, `log-forwarder` |
| `dashboard` | Local reports and AI assessment | `report-dashboard`, `ollama-assessor` |
| `monitor` | Uptime monitoring | `uptime-kuma` |
| `backup` | Persistent volume backups only | `volume-backup` |
| `scanner` | Container image vulnerability scans only | `container-vuln-scanner` |
| `brain` | SIEM and log analysis | Wazuh, Graylog, MongoDB, Graylog Data Node |
| `network` | Network detection | Suricata, Zeek |
| `ir` | Incident response | TheHive, Shuffle, Velociraptor, Ansible |
| `vuln` | Vulnerability and hardening | osquery, Greenbone Community |
| `all` | Full lab stack | All services |

## Lifecycle Scripts

Use the lifecycle scripts from the repository root on the Linux Docker host.

Start/bootstrap:

```bash
sh scripts/start-stack.sh
```

What it does:

- Creates `.env` from `.env.example` if missing.
- Creates local runtime directories for backups, reports, SSH keys, and Suricata rules.
- Applies `vm.max_map_count=262144` when possible.
- Runs `docker compose ... config`.
- Pulls images by default.
- Starts selected profiles with `up -d --remove-orphans`.
- Waits for health checks unless `WAIT_HEALTH=false`.

Useful options:

```bash
SECSTACK_PROFILES="dns secrets brain" sh scripts/start-stack.sh
PULL_IMAGES=false sh scripts/start-stack.sh
WAIT_HEALTH=false sh scripts/start-stack.sh
```

Killswitch:

```bash
sh scripts/killswitch.sh
```

Modes:

```bash
sh scripts/killswitch.sh stop   # default; graceful stop, preserve volumes
sh scripts/killswitch.sh down   # remove containers/networks, preserve volumes
sh scripts/killswitch.sh pause  # pause running containers
```

The killswitch never removes named volumes, `./The Hands/backups`, or `./The Hands/reports/data`.

## Services, Ports, And Endpoints

| Service | Container | Host endpoint | FQDN | Internal endpoint |
| --- | --- | --- | --- | --- |
| CoreDNS | `secdns` | `127.0.0.1:1053` TCP/UDP | `coredns.hq-sec.local` | `secdns:53` |
| FQDN proxy | `fqdn-proxy` | `0.0.0.0:80` | service FQDN target | `fqdn-proxy:80` |
| Vault | `vault` | `localhost:8200` | `vault.hq-sec.local` | `vault:8200` |
| Ollama API | `ollama` | `http://localhost:11434` | `ollama.hq-sec.local` | `http://ollama:11434` |
| Ollama model pull | `ollama-model-pull` | none | none | pulls `${OLLAMA_MODEL:-llama3.2}` |
| Ollama assessor | `ollama-assessor` | none | none | scheduled LLM analysis and reports |
| Wazuh Dashboard | `wazuh-dashboard` | `https://localhost:5601` | `wazuh.hq-sec.local` | `https://wazuh-dashboard:5601` |
| Wazuh API | `wazuh-manager` | `https://localhost:55000` | `wazuh-api.hq-sec.local` | `https://wazuh-manager:55000` |
| Wazuh events | `wazuh-manager` | `localhost:1514/udp` | none | `wazuh-manager:1514/udp` |
| Wazuh enrollment | `wazuh-manager` | `localhost:1515/tcp` | none | `wazuh-manager:1515/tcp` |
| Wazuh Indexer | `wazuh-indexer` | `https://localhost:9200` | `wazuh-indexer.hq-sec.local` | `https://wazuh-indexer:9200` |
| Graylog | `graylog` | `http://localhost:9000` | `graylog.hq-sec.local` | `http://graylog:9000` |
| Graylog GELF | `graylog` | `localhost:12201/udp` | none | `graylog:12201/udp` |
| --- | --- |
| Wazuh rules and FIM | `The Brain/Wazuh/rules/local_rules.xml`, `The Brain/Wazuh/agent/ossec.conf` |
| PowerShell logging | `The Sword/Windows/powershell/Install-PowerShellLoggingTask.ps1`, `The Sword/Windows/powershell/Collect-PowerShellActivity.ps1` |
| Sysmon | `The Sword/Windows/sysmon/sysmon-hq-sec.xml` |
| Suricata IDS | `The Sword/Suricata/suricata.yaml`, `The Sword/Suricata/rules/local.rules` |
| Suricata community definitions | `The Sword/Suricata/update/*`, `docs/suricata-rulesets.md` |
| Graylog filters | `The Eyes/Graylog/queries/security-filters.md` |
| TheHive flow | `The Eyes/thehive/alert-flow.md` |
| Velociraptor hunts | `The Shield/velociraptor/hunt-plan.md` |
| Ansible response | `The Sword/Ansible/playbooks/windows-contain-malicious.yml`, `The Sword/Ansible/playbooks/windows-isolate.yml`, `The Sword/Ansible/playbooks/windows-applocker-containment.yml`, `The Sword/Ansible/playbooks/windows-collect-artifacts.yml` |

See [docs/windows-endpoint-detection.md](docs/windows-endpoint-detection.md) for the full telemetry and response flow.

## Backup And Recovery

All stateful services use named Docker volumes. That data persists across normal container restarts, reboots, and `docker compose up/down` as long as volumes are not removed.

The `volume-backup` service creates compressed archives for persistent named volumes:

```bash
docker compose -f security-stack.compose.yml --profile backup up -d
docker logs volume-backup --tail 100
ls "The Hands/backups/"
```

Defaults:

- Runs once on startup: `BACKUP_RUN_ON_STARTUP=true`
- Runs every 24 hours: `BACKUP_INTERVAL_SECONDS=86400`
- Prunes backups older than 30 days: `BACKUP_RETENTION_DAYS=30`
- Writes archives and `SHA256SUMS` under `./The Hands/backups/<timestamp>/`

Transient socket volumes are intentionally excluded because they are runtime IPC, not recoverable data.

For the most consistent database backups, stop the affected profile before a manual snapshot:

```bash
docker compose -f security-stack.compose.yml --profile brain stop
docker compose -f security-stack.compose.yml --profile backup run --rm -e BACKUP_ONCE=true volume-backup
docker compose -f security-stack.compose.yml --profile brain start
```

Restore pattern:

```bash
docker run --rm \
  -v hq-sec-stack_graylog-data:/restore \
  -v "./The Hands/backups:/backups:ro" \
  -v "./The Hands/backup/scripts:/backup/scripts:ro" \
  alpine:3.20 \
  sh /backup/scripts/restore-volume.sh graylog-data /backups/<timestamp>/graylog-data.tar.gz
```

## Container Vulnerability Scanning

`container-vuln-scanner` uses Trivy to scan the image targets listed in `The Shield/scanner/targets.txt` and writes reports under `./The Hands/reports/data/container-vulnerabilities`.

```bash
docker compose -f security-stack.compose.yml --profile scanner up -d
docker logs container-vuln-scanner --tail 100
ls "The Hands/reports/data/container-vulnerabilities/latest"
```

Defaults:

- Scanner image: `aquasec/trivy:0.70.0`
- Runs once on startup: `TRIVY_RUN_ON_STARTUP=true`
- Runs every 24 hours: `TRIVY_SCAN_INTERVAL_SECONDS=86400`
- Flags `HIGH,CRITICAL` findings by default
- Produces JSON and table reports plus a Markdown summary

Keep `The Shield/scanner/targets.txt` aligned with image changes in `security-stack.compose.yml`. Trivy `v0.70.0` is pinned because Aqua Security disclosed a 2026 supply-chain incident affecting parts of the `0.69.x` ecosystem. Avoid floating the scanner image without reviewing current advisories.

## Uptime Monitoring

The stack uses [Uptime Kuma](https://hub.docker.com/r/louislam/uptime-kuma) as the open-source uptime dashboard. It is available at:

```text
http://uptime.hq-sec.local
http://localhost:3002
```

Create monitors for the FQDNs and internal endpoints listed in the services table. Use HTTP monitors for dashboards/APIs and TCP/UDP checks where applicable.

The desired monitor inventory is tracked in `The Eyes/Uptime-Kuma/monitors.yml` and reconciled by `uptime-kuma-sync` when `UPTIME_KUMA_PASSWORD` is set in `.env`. See [docs/uptime-dashboard.md](docs/uptime-dashboard.md).

Repository rule: every new service, container, FQDN, host port, or internal endpoint must be added to `The Eyes/Uptime-Kuma/monitors.yml` in the same change.

## Service Categories

Services are documented by category in [docs/service-categories.md](docs/service-categories.md):

1. Alert, Visualization & SIEM: The Brain
2. Network Monitoring: The Eyes
3. Incident Response & Automation: The Shield
4. Endpoint Vulnerability, Protection, and Hardening: The Sword
5. Support Services: The Hands

Top-level service folders now follow that taxonomy:

```text
The Brain/
The Eyes/
The Shield/
The Sword/
The Hands/
```

## File Path Mapping

| Previous path | Current path | Function |
| --- | --- | --- |
| `wazuh/` | `The Brain/Wazuh/` | Wazuh rules, agent configuration, and SIEM artifacts |
| `ollama/` | `The Brain/Ollama/` | Local LLM analysis scripts and persona assets |
| `ossec/` | `The Brain/OSSEC/` | OSSEC host intrusion detection artifacts |
| `graylog/` | `The Eyes/Graylog/` | Graylog bootstrap, queries, and visualization support |
| `fluent-bit/` | `The Eyes/Fluent Bit/` | Log collection, parsing, and forwarding configuration |
| `thehive/` | `The Eyes/thehive/` | Case intake and alert investigation configuration |
| `uptime-kuma/` | `The Eyes/Uptime-Kuma/` | Uptime monitor inventory and sync scripts |
| `vault/` | `The Shield/vault/` | Vault config, policies, secret manifests, and rotation scripts |
| `scanner/` | `The Shield/scanner/` | Trivy container vulnerability targets and scanner scripts |
| `velociraptor/` | `The Shield/velociraptor/` | Endpoint hunt and forensic collection plans |
| `suricata/` | `The Sword/Suricata/` | IDS config, local rules, and community ruleset update config |
| `ansible/` | `The Sword/Ansible/` | Incident response and hardening playbooks |
| `windows/` | `The Sword/Windows/` | PowerShell logging, Sysmon, and AppLocker endpoint artifacts |
| `dns/` | `The Hands/CoreDNS/` | Local `hq-sec.local` DNS records and CoreDNS config |
| `proxy/` | `The Hands/FQDN proxy - Caddy/` | FQDN reverse proxy routes |
| `backup/` | `The Hands/backup/` | Volume backup and restore scripts |
| `assessment/` | `The Hands/log assessor/` | Legacy local assessment support path |
| `dashboard/` | `The Hands/reports/dashboard-ui/` | Static report dashboard UI |
| `reports/` | `The Hands/reports/data/` | Generated reports, assessments, and vulnerability output |

Some categories also include pointer folders so a service can appear in more than one operational role without duplicating its live configuration: `The Eyes/Wazuh/`, `The Eyes/sysmon/`, `The Shield/osquery/`, `The Shield/openvas/`, `The Shield/shuffle/`, `The Hands/Vault/`, and `The Hands/Fluent Bit/`.

## Workflow Mapping

| Workflow | Primary paths | Output or handoff |
| --- | --- | --- |
| Local DNS and FQDN routing | `The Hands/CoreDNS/`, `The Hands/FQDN proxy - Caddy/` | Service FQDNs under `hq-sec.local` route to Compose service names |
| Log collection and SIEM visibility | `The Eyes/Fluent Bit/`, `The Eyes/Graylog/`, `The Brain/Wazuh/` | Graylog streams/search, Wazuh alerts, dashboard views |
| Daily AI assessment and reports | `The Brain/Ollama/`, `The Hands/reports/dashboard-ui/`, `The Hands/reports/data/` | `assessment.md`, `assessment.json`, and `reports.hq-sec.local` |
| Secrets and rotation | `The Shield/vault/` | Vault KV paths and `.env.vault` rendered service variables |
| Backup and recovery | `The Hands/backup/`, `The Hands/backups/` | Timestamped named-volume archives and checksums |
| Container vulnerability observation | `The Shield/scanner/`, `The Hands/reports/data/container-vulnerabilities/` | Trivy JSON/table reports and AI triage evidence |
| Network IDS | `The Sword/Suricata/` | Suricata alerts forwarded into Graylog/Wazuh |
| Endpoint telemetry and hardening | `The Sword/Windows/`, `The Sword/Ansible/` | Windows logs, Sysmon evidence, isolation and hardening playbooks |
| Incident response and forensics | `The Eyes/thehive/`, `The Shield/velociraptor/`, `The Sword/Ansible/` | Cases, tasks, endpoint collections, response actions |
| Availability monitoring | `The Eyes/Uptime-Kuma/` | Uptime Kuma monitors for every service URL and health endpoint |

## Log Dashboard And Daily AI Assessment

Start the report dashboard and daily assessor:

```bash
docker compose -f security-stack.compose.yml --profile dashboard --profile logs up -d
```

This starts `graylog-bootstrap`, `log-forwarder`, `report-dashboard`, Ollama, and `ollama-assessor`. Keep `GRAYLOG_ROOT_PASSWORD` in `.env` or `.env.vault` aligned with the actual Graylog admin password so Graylog API queries can authenticate.

Open:

```text
http://reports.hq-sec.local
```

The dashboard reads `./The Hands/reports/data/log-assessments/latest/assessment.json`. The `ollama-assessor` service queries Graylog, samples mounted evidence, calls Ollama, and produces:

```text
The Hands/reports/data/log-assessments/<date>/assessment.json
The Hands/reports/data/log-assessments/<date>/assessment.md
The Hands/reports/data/log-assessments/latest/assessment.json
The Hands/reports/data/log-assessments/latest/assessment.md
```

The assessment is an evidence-bounded local LLM summary for daily triage. Graylog remains the source of truth for full-fidelity search, streams, alerts, and dashboards.

Run a one-shot assessment:

```bash
docker compose -f security-stack.compose.yml --profile llm run --rm -e OLLAMA_ANALYSIS_ONCE=true ollama-assessor
```

## GitHub Actions Deployment

The workflow at `.github/workflows/build-deploy.yml` validates Compose and scripts on every pull request and push to `main`.

Manual deployment uses `workflow_dispatch` and requires these repository secrets:

```text
DEPLOY_HOST
DEPLOY_USER
DEPLOY_SSH_KEY
DEPLOY_PATH
DEPLOY_PORT
```

Optional repository variable:

```text
SECSTACK_PROFILES=dns secrets brain ops
```

## Validation

```bash
sh scripts/start-stack.sh
sh scripts/killswitch.sh
docker compose -f security-stack.compose.yml --profile all config
docker compose -f security-stack.compose.yml --profile dns --profile secrets up -d
docker compose -f security-stack.compose.yml ps
dig @127.0.0.1 -p 1053 vault.hq-sec.local
curl http://vault.hq-sec.local/v1/sys/health
docker compose -f security-stack.compose.yml --profile backup run --rm -e BACKUP_ONCE=true volume-backup
docker compose -f security-stack.compose.yml --profile scanner run --rm -e TRIVY_SCAN_ONCE=true container-vuln-scanner
docker compose -f security-stack.compose.yml --profile llm run --rm -e OLLAMA_ANALYSIS_ONCE=true ollama-assessor
```

## Important Safety Notes

This is a lab stack. Replace all default passwords and secrets before using it beyond a private test environment.

Privileged exceptions:

- Suricata and Zeek require host networking and packet-capture capabilities.
- Shuffle mounts `/var/run/docker.sock`, which is host-root equivalent.
- `container-health-exporter` reads `/var/run/docker.sock` so Uptime Kuma can monitor worker containers; keep it internal.
- osquery mounts `/` read-only as `/host`.
- Greenbone scanner components require network scanning capabilities and relaxed scanner security options.

Do not run vulnerability scans, containment playbooks, or endpoint collection against systems without authorization.


