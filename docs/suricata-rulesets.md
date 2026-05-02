# Suricata Community IDS Definitions

This stack uses `suricata-update`, the official Suricata rule-management tool, to install and refresh community IDS definitions.

## Enabled Sources

Defaults are set in `.env.example`:

```text
SURICATA_UPDATE_ENABLE_SOURCES=et/open oisf/trafficid ptresearch/attackdetection sslbl/ssl-fp-blacklist sslbl/ja3-fingerprints abuse.ch/sslbl-c2 abuse.ch/urlhaus
```

| Source | Purpose |
| --- | --- |
| `et/open` | Emerging Threats Open community IDS signatures |
| `oisf/trafficid` | OISF traffic identification rules |
| `ptresearch/attackdetection` | Positive Technologies attack-detection rules |
| `sslbl/ssl-fp-blacklist` | abuse.ch SSL certificate fingerprint detections |
| `sslbl/ja3-fingerprints` | abuse.ch malicious JA3 TLS fingerprint detections |
| `abuse.ch/sslbl-c2` | abuse.ch C2 IP/port indicators where available |
| `abuse.ch/urlhaus` | abuse.ch URLhaus malware URL IDS rules where available |

Availability depends on the current OISF `suricata-update` source index. The update script logs and continues if a named source is unavailable in the installed `suricata-update` version.

## Update Commands

One-shot update:

```bash
docker compose -f security-stack.compose.yml --profile network run --rm -e SURICATA_UPDATE_ONCE=true suricata-rules-update
```

Scheduled update:

```bash
docker compose -f security-stack.compose.yml --profile network up -d suricata-rules-update
```

Rules are written to `./The Sword/Suricata/rules` on the host and mounted into the sensor at `/var/lib/suricata/rules`.

## Local Rules Overlay

Local lab rules remain in:

```text
The Sword/Suricata/rules/local.rules
```

The updater copies that file into the managed rules directory and `suricata.yaml` loads both:

```yaml
rule-files:
  - suricata.rules
  - local.rules
```

## Tuning Files

Use these files for tuning:

- `The Sword/Suricata/update/enable.conf`
- `The Sword/Suricata/update/disable.conf`
- `The Sword/Suricata/update/drop.conf`
- `The Sword/Suricata/update/modify.conf`
- `The Sword/Suricata/update/threshold.config`

This stack runs Suricata as IDS by default. Do not convert rules to `drop` unless you intentionally deploy inline IPS mode.

