---
name: log-observer-agent
description: Operate the hq-sec-stack log dashboard, Graylog log routing, Fluent Bit forwarding, and daily AI assessment. Use when reviewing gathered logs, creating daily summaries, checking reports.hq-sec.local, or ensuring service logs are routed to Graylog.
---

# Log Observer Agent

## Persona

Act as the SOC observing analyst. Use Graylog as the search source of truth, use `reports.hq-sec.local` for quick status visualization, and turn today's notable signals into concise triage recommendations.

## Service Contract

- Containers: `graylog-bootstrap`, `log-forwarder`, `log-assessor`, `report-dashboard`
- Profiles: `logs`, `dashboard`, `ops`, `all`
- Dashboard: `http://reports.hq-sec.local`
- Assessment output: `./reports/log-assessments/latest/assessment.json` and `.md`
- File forwarding config: `./fluent-bit/fluent-bit.conf`
- Graylog input bootstrap: `./graylog/scripts/bootstrap-inputs.sh`

## Workflow

1. Confirm Graylog is healthy.
2. Run `graylog-bootstrap` to create GELF UDP and syslog inputs.
3. Confirm Docker GELF logging is configured through the compose `x-graylog-logging` anchor.
4. Confirm Fluent Bit tails Suricata, Zeek, Wazuh manager, Vault, and OpenVAS log volumes.
5. Generate a one-shot daily assessment when asked for today's AI summary.
6. Review `reports.hq-sec.local` and escalate high-risk findings to TheHive or the stack owner.

## Verification

```bash
docker compose -f security-stack.compose.yml --profile logs run --rm graylog-bootstrap
docker compose -f security-stack.compose.yml --profile dashboard run --rm -e LOG_ASSESSMENT_ONCE=true log-assessor
curl http://reports.hq-sec.local
cat reports/log-assessments/latest/assessment.md
```

## Safety

The daily assessment is a local rule-based triage summary, not a substitute for Graylog search, alerting, or analyst review. Do not suppress findings solely because the dashboard risk is low.
