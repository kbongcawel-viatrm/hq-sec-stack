# The Ghost

> *"The soul behind the body parts. Pulling the strings. Making everyone better."*

The Ghost is the LLM governance layer of the hq-sec-stack. It sits above all other pillars — not as a peer, but as the reasoning intelligence that observes, interprets, and advises across every one of them.

While the other pillars collect, detect, protect, and respond, **The Ghost understands**.

## Services

- `ollama` — Local LLM runtime. Hosts the model (default: `llama3.2`) on the internal `secnet` network.
- `ollama-model-pull` — One-shot initializer that pulls the configured model on first boot.
- `ollama-assessor` — The active reasoning engine. Ingests log evidence from all pillars and produces structured security assessments.

## Pillar Responsibilities & Governance

The Ghost acts as the soul of the stack, governing the body parts with specific intent:

- **The Eyes** — Reads perception services to gain situational awareness and perform deeper analysis of network/traffic patterns.
- **The Brain** — Uses SIEM and cognition services to correlate alerts and make sound architectural decisions or detection improvements.
- **The Shield** — Identifies hardening gaps in secrets, vulnerabilities, and endpoint configurations to strengthen the defense.
- **The Sword** — Directs response actions (IP blocks, containment, IDS rules) to neutralize active issues.
- **The Hands** — Monitors infrastructure health (DNS, proxy, backups) to ensure the stack remains supported and operational.

The Ghost reads from every pillar and reasons across all of them:

| Pillar | Category | Evidence Consumed |
|---|---|---|
| **The Eyes** | Perception | Graylog events, TheHive cases, Uptime-Kuma status, Caddy logs |
| **The Brain** | Cognition | Wazuh logs, OSSEC alerts, SIEM correlation |
| **The Shield** | Protection | Vault audits, OpenVAS findings, Trivy scans, osquery results |
| **The Sword** | Action | Suricata IPS alerts, CrowdSec blocks, Ansible activity |
| **The Hands** | Support | CoreDNS health, Caddy health, Backup status, Report delivery |

## Output

The Ghost writes two distinct report trees (accessible via **The Hands** dashboard):

### 1. Log Assessments
`The Hands/reports/data/log-assessments/latest/`
- `assessment.md` — The master human-readable report.
- `assessment.json` — Structured summary for dashboard integration.

### 2. Ghost Directives
`The Hands/reports/ghost-directives/latest/`
- `ghost-directives.md` — Top 5 high-impact cross-pillar directives.
- `eyes.md`, `brain.md`, `shield.md`, `sword.md`, `hands.md` — Specific, actionable commands and recommendations for each individual pillar.

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

## Swapping the Ghost's Brain (Models)

If `llama3.2` performance is insufficient for your analysis needs, you can easily swap the underlying model. The stack supports pre-pulling multiple models so you can switch between them without waiting for a download.

### 1. Pre-pulling Multiple Models
In your `.env` file, list all models you want the Ghost to have ready:
```bash
OLLAMA_MODELS_TO_PULL="llama3.2 mistral llama3.1 gemma2"
```

### 2. Changing the Active Model
To change which model the Ghost currently uses for analysis, update the active variable and restart the assessor:
```bash
# In .env
OLLAMA_MODEL=mistral

# Then restart the assessor
docker compose -f security-stack.compose.yml --profile ghost up -d ollama-assessor
```

### Recommended Alternatives
| Model | Rationale |
|---|---|
| `llama3.1` | Much stronger reasoning and instruction following than 3.2. |
| `mistral` | Highly reliable, balanced performance for security log analysis. |
| `gemma2` | Excellent at summarizing complex data and identifying patterns. |
| `phi3` | Fast and lightweight if resource usage is a concern. |

## Configuration

Key environment variables (set in `.env`):

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_MODEL` | `llama3.2` | Active model used by the Ghost for analysis. |
| `OLLAMA_MODELS_TO_PULL` | `llama3.2` | Space-separated list of models to pre-load on startup. |
| `OLLAMA_ANALYSIS_CRON` | `0 2 * * *` | Schedule for recurring analysis (daily at 02:00 UTC) |
| `OLLAMA_ANALYSIS_RUN_ON_STARTUP` | `true` | Run an analysis immediately on container start |
| `OLLAMA_ANALYSIS_MAX_LOG_LINES` | `2500` | Max log lines sampled per analysis run |
| `OLLAMA_ANALYSIS_CONTEXT_CHARS` | `24000` | Max characters of evidence sent to the LLM |
