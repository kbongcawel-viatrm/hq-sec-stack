# HQ Security Stack

Linux Docker Compose lab for SOC monitoring, network visibility, incident response, vulnerability management, local DNS, and secrets management.

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
| `dashboard` | Local reports and AI assessment | `report-dashboard`, `log-assessor` |
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

The killswitch never removes named volumes, `./backups`, or `./reports`.

## Services, Ports, And Endpoints

| Service | Container | Host endpoint | FQDN | Internal endpoint |
| --- | --- | --- | --- | --- |
| CoreDNS | `secdns` | `127.0.0.1:1053` TCP/UDP | `coredns.hq-sec.local` | `secdns:53` |
| FQDN proxy | `fqdn-proxy` | `0.0.0.0:80` | service FQDN target | `fqdn-proxy:80` |
| Vault | `vault` | `localhost:8200` | `vault.hq-sec.local` | `vault:8200` |
| Wazuh Dashboard | `wazuh-dashboard` | `https://localhost:5601` | `wazuh.hq-sec.local` | `https://wazuh-dashboard:5601` |
| Wazuh API | `wazuh-manager` | `https://localhost:55000` | `wazuh-api.hq-sec.local` | `https://wazuh-manager:55000` |
| Wazuh events | `wazuh-manager` | `localhost:1514/udp` | none | `wazuh-manager:1514/udp` |
| Wazuh enrollment | `wazuh-manager` | `localhost:1515/tcp` | none | `wazuh-manager:1515/tcp` |
| Wazuh Indexer | `wazuh-indexer` | `https://localhost:9200` | `wazuh-indexer.hq-sec.local` | `https://wazuh-indexer:9200` |
| Graylog | `graylog` | `http://localhost:9000` | `graylog.hq-sec.local` | `http://graylog:9000` |
| Graylog GELF | `graylog` | `localhost:12201/udp` | none | `graylog:12201/udp` |
| Graylog syslog | `graylog` | `localhost:5514/tcp`, `5514/udp` | none | `graylog:1514/tcp`, `1514/udp` |
| TheHive | `thehive` | `http://localhost:9001` | `thehive.hq-sec.local` | `http://thehive:9000` |
| Shuffle frontend | `shuffle` | `http://localhost:3001` | `shuffle.hq-sec.local` | `http://shuffle:3001` |
| Shuffle backend | `shuffle` | `http://localhost:5001` | `shuffle-api.hq-sec.local` | `http://shuffle:5001` |
| Velociraptor GUI | `velociraptor` | `http://localhost:8889` | `velociraptor.hq-sec.local` | `http://velociraptor:8889` |
| Velociraptor frontend | `velociraptor` | `localhost:8000` | none | `velociraptor:8000` |
| Greenbone GSA | `greenbone-nginx` | `https://localhost:9443`, `localhost:9392` | `greenbone.hq-sec.local` | `https://greenbone-nginx:443` |
| Suricata | `suricata` | host network capture | none | writes `suricata-logs` |
| Zeek | `zeek` | host network capture | none | writes `zeek-logs` |
| Ansible IR | `ansible-ir` | none | none | shell/playbook runner on `secnet` |
| osquery | `osquery` | interactive shell | none | read-only `/host` helper |
| Volume backup | `volume-backup` | none | none | archives named volumes to `./backups` |
| Container scanner | `container-vuln-scanner` | none | none | writes Trivy reports to `./reports/container-vulnerabilities` |
| Log forwarder | `log-forwarder` | none | none | tails service log volumes to Graylog GELF |
| Graylog bootstrap | `graylog-bootstrap` | none | none | creates GELF and syslog inputs in Graylog |
| Report dashboard | `report-dashboard` | none | `reports.hq-sec.local` | `http://report-dashboard:80` |
| Log assessor | `log-assessor` | none | none | writes daily assessment to `./reports/log-assessments` |

## Network And DNS

`secnet` uses `${SECNET_CIDR:-10.77.0.0/24}` with gateway `${SECNET_GATEWAY:-10.77.0.1}`. CoreDNS is assigned `10.77.0.53`; the FQDN proxy is assigned `10.77.0.80`.

All human-facing FQDNs resolve to `10.77.0.80`. Treat that address as the single `/32` service target, `10.77.0.80/32`. The Docker network itself cannot be `/32` because the stack has many containers.

Test DNS:

```bash
dig @127.0.0.1 -p 1053 graylog.hq-sec.local
curl http://graylog.hq-sec.local
```

For systemd-resolved:

```bash
sudo resolvectl dns docker0 10.77.0.53
sudo resolvectl domain docker0 '~hq-sec.local'
resolvectl query vault.hq-sec.local
```

## Secrets Management

Vault runs under the `secrets` profile with file storage:

```bash
docker compose -f security-stack.compose.yml --profile secrets up -d vault
docker compose -f security-stack.compose.yml --profile secrets exec vault vault operator init
docker compose -f security-stack.compose.yml --profile secrets exec vault vault operator unseal
```

After initialization, enable KV v2 and create the rotator policy/token:

```bash
docker compose -f security-stack.compose.yml --profile secrets exec vault vault secrets enable -path=secret kv-v2
docker compose -f security-stack.compose.yml --profile secrets exec vault vault policy write secstack-rotator /vault/policies/secstack-rotator.hcl
docker compose -f security-stack.compose.yml --profile secrets exec vault vault token create -policy=secstack-rotator -period=720h
```

Put the generated token into `.env` as `VAULT_ROTATOR_TOKEN`. Do not commit it.

The `vault-rotator` container checks every `${VAULT_ROTATION_CHECK_SECONDS:-21600}` seconds and rotates once per month on `${VAULT_ROTATION_DAY:-1}`. It writes generated values under:

```text
secret/data/hq-sec-stack/graylog/password-secret
secret/data/hq-sec-stack/graylog/root-password
secret/data/hq-sec-stack/wazuh/dashboard-password
secret/data/hq-sec-stack/thehive/play-secret
secret/data/hq-sec-stack/shuffle/app-secret
secret/data/hq-sec-stack/greenbone/admin-password
secret/data/hq-sec-stack/velociraptor/admin-password
```

These are stored in Vault, not committed to the repo. Static application secrets still require an operator workflow to apply the rotated value to each service and restart/reload the affected container. This is intentional for a lab stack because several upstream images expect static environment variables or app-specific password hashes.

## Interconnection

Endpoint telemetry enters Wazuh on `1514/udp` and `1515/tcp`; Wazuh indexes through `wazuh-indexer` and presents through `wazuh-dashboard`.

General logs enter Graylog through GELF `12201/udp` or syslog `5514`. Graylog stores metadata in MongoDB and search data in Graylog Data Node.

Container stdout/stderr is pointed at Graylog through Docker's GELF logging driver. `graylog-bootstrap` creates Graylog GELF and syslog inputs through the Graylog API. File-based logs from Suricata, Zeek, Wazuh manager, Vault, and OpenVAS are tailed by Fluent Bit through `log-forwarder` and sent to Graylog GELF.

Suricata and Zeek capture on `${SENSOR_INTERFACE}` with host networking and write logs to named volumes.

Wazuh and Graylog alerts become TheHive cases. Shuffle coordinates approved workflows. Velociraptor collects endpoint evidence. Ansible runs response playbooks. Greenbone and osquery add vulnerability and host-state context.

Vault stores lab secrets and monthly rotated values. Service credentials should be migrated from `.env` defaults into Vault-backed operating procedures as integrations mature.

## Backup And Recovery

All stateful services use named Docker volumes. That data persists across normal container restarts, reboots, and `docker compose up/down` as long as volumes are not removed.

The `volume-backup` service creates compressed archives for persistent named volumes:

```bash
docker compose -f security-stack.compose.yml --profile backup up -d
docker logs volume-backup --tail 100
ls backups/
```

Defaults:

- Runs once on startup: `BACKUP_RUN_ON_STARTUP=true`
- Runs every 24 hours: `BACKUP_INTERVAL_SECONDS=86400`
- Prunes backups older than 30 days: `BACKUP_RETENTION_DAYS=30`
- Writes archives and `SHA256SUMS` under `./backups/<timestamp>/`

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
  -v ./backups:/backups:ro \
  -v ./backup/scripts:/backup/scripts:ro \
  alpine:3.20 \
  sh /backup/scripts/restore-volume.sh graylog-data /backups/<timestamp>/graylog-data.tar.gz
```

## Container Vulnerability Scanning

`container-vuln-scanner` uses Trivy to scan the image targets listed in `scanner/targets.txt` and writes reports under `./reports/container-vulnerabilities`.

```bash
docker compose -f security-stack.compose.yml --profile scanner up -d
docker logs container-vuln-scanner --tail 100
ls reports/container-vulnerabilities/latest
```

Defaults:

- Scanner image: `aquasec/trivy:0.70.0`
- Runs once on startup: `TRIVY_RUN_ON_STARTUP=true`
- Runs every 24 hours: `TRIVY_SCAN_INTERVAL_SECONDS=86400`
- Flags `HIGH,CRITICAL` findings by default
- Produces JSON and table reports plus a Markdown summary

Keep `scanner/targets.txt` aligned with image changes in `security-stack.compose.yml`. Trivy `v0.70.0` is pinned because Aqua Security disclosed a 2026 supply-chain incident affecting parts of the `0.69.x` ecosystem. Avoid floating the scanner image without reviewing current advisories.

## Log Dashboard And Daily AI Assessment

Start the report dashboard and daily assessor:

```bash
docker compose -f security-stack.compose.yml --profile dashboard --profile logs up -d
```

This starts `graylog-bootstrap`, `log-forwarder`, `report-dashboard`, and `log-assessor`. Keep `GRAYLOG_ROOT_PASSWORD` in `.env` aligned with the actual Graylog admin password so input bootstrap can authenticate.

Open:

```text
http://reports.hq-sec.local
```

The dashboard reads `./reports/log-assessments/latest/assessment.json`. The `log-assessor` service samples mounted log files and produces:

```text
reports/log-assessments/<date>/assessment.json
reports/log-assessments/<date>/assessment.md
reports/log-assessments/latest/assessment.json
reports/log-assessments/latest/assessment.md
```

The assessment is a local rule-based AI-style summary for daily triage. Graylog remains the source of truth for full-fidelity search, streams, alerts, and dashboards.

Run a one-shot assessment:

```bash
docker compose -f security-stack.compose.yml --profile dashboard run --rm -e LOG_ASSESSMENT_ONCE=true log-assessor
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
docker compose -f security-stack.compose.yml --profile dashboard run --rm -e LOG_ASSESSMENT_ONCE=true log-assessor
```

## Important Safety Notes

This is a lab stack. Replace all default passwords and secrets before using it beyond a private test environment.

Privileged exceptions:

- Suricata and Zeek require host networking and packet-capture capabilities.
- Shuffle mounts `/var/run/docker.sock`, which is host-root equivalent.
- osquery mounts `/` read-only as `/host`.
- Greenbone scanner components require network scanning capabilities and relaxed scanner security options.

Do not run vulnerability scans, containment playbooks, or endpoint collection against systems without authorization.
