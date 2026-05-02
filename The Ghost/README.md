# The Ghost

> *"The soul behind the body parts. Pulling the strings. Making everyone better."*

The Ghost is the LLM governance layer of the hq-sec-stack. It sits above all other pillars — not as a peer, but as the reasoning intelligence that observes, interprets, and advises across every one of them.

While the other pillars collect, detect, protect, and respond, **The Ghost understands**.

## Services

- `ollama` — Local LLM runtime. Hosts the model (default: `llama3.2`) on the internal `secnet` network.
- `ollama-model-pull` — One-shot initializer that pulls the configured model on first boot.
- `ollama-assessor` — The active reasoning engine. Ingests log evidence from all pillars and produces structured security assessments.

## What It Governs

The Ghost reads from every pillar and reasons across all of them:

| Pillar | Evidence Consumed |
|---|---|
| **The Brain** | Graylog aggregated events, Wazuh/OSSEC alerts |
| **The Eyes** | Suricata IDS logs, Zeek network logs |
| **The Shield** | Vault audit logs, OpenVAS vulnerability findings, Trivy container scan results |
| **The Sword** | Suricata alerts, CrowdSec block events |

## Output

Reports are written to `The Hands/reports/data/log-assessments/`:

- `latest/assessment.md` — Human-readable Markdown security assessment
- `latest/assessment.json` — Machine-readable structured summary
- `<date>/assessment.md` — Historical archive per run date

Each report contains:
- **Executive Risk** — Overall risk posture (low / medium / high)
- **Key Evidence** — High-signal events across all log sources
- **Suspected Attack Patterns** — LLM-inferred threat activity
- **Hardening Recommendations** — Actionable security improvements
- **Incident Response Plan** — Step-by-step response guidance
- **Ansible Playbook Ideas** — Automation suggestions for The Sword
- **Follow-Up Queries For Graylog** — Queries to drill deeper

## Profile

```bash
# Start The Ghost only
docker compose -f security-stack.compose.yml --profile ghost up -d

# Alias
docker compose -f security-stack.compose.yml --profile llm up -d
```

## Configuration

Key environment variables (set in `.env`):

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_MODEL` | `llama3.2` | Model to pull and use for analysis |
| `OLLAMA_ANALYSIS_CRON` | `0 2 * * *` | Schedule for recurring analysis (daily at 02:00 UTC) |
| `OLLAMA_ANALYSIS_RUN_ON_STARTUP` | `true` | Run an analysis immediately on container start |
| `OLLAMA_ANALYSIS_MAX_LOG_LINES` | `2500` | Max log lines sampled per analysis run |
| `OLLAMA_ANALYSIS_CONTEXT_CHARS` | `24000` | Max characters of evidence sent to the LLM |
