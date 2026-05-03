# The Ghost

> *"The soul behind the body parts. Pulling the strings. Making everyone better."*

The Ghost is the LLM governance layer of the hq-sec-stack. It sits above all other pillars — not as a peer, but as the reasoning intelligence that observes, interprets, and advises across every one of them.

While the other pillars collect, detect, protect, and respond, **The Ghost understands**.

## Services

- `ghost` — Local LLM runtime. Hosts local open-weight models on the internal `secnet` network.
- `ghost-model-pull` — One-shot initializer that pulls the configured local models on first boot.
- `ghost-assessor` — The active reasoning engine (The Soul). Ingests log evidence from all pillars and produces structured security assessments and directives.

## Pillar Responsibilities & Governance

The Ghost acts as the soul of the stack, governing the body parts with specific intent:

- **The Eyes** — Reads perception services to gain situational awareness and perform deeper analysis of network/traffic patterns.
- **The Brain** — Uses SIEM and cognition services to correlate alerts and make sound architectural decisions or detection improvements.
- **The Shield** — Identifies hardening gaps in secrets, vulnerabilities, and endpoint configurations to strengthen the defense.
- **The Sword** — Directs response actions (IP blocks, containment, IDS rules) to neutralize active issues.
- **The Hands** — Monitors infrastructure health (DNS, proxy, backups) to ensure the stack remains supported and operational.

## What It Governs

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

## Swapping the Ghost's Brain (Local vs. Cloud)

The Ghost can inhabit various models depending on your needs. For the ultimate analysis performance, you can use **ChatGPT (GPT-4 Turbo)**. For complete privacy and offline operation, you can use local models via **The Ghost runtime**.

### 1. Using ChatGPT (Highest Performance)
To use ChatGPT as the Ghost's engine, set your API key and model in `.env`:
```bash
# In .env
GHOST_MODEL=gpt-4-turbo
OPENAI_API_KEY=sk-your-key-here
```
*The Ghost will automatically detect the 'gpt' prefix and use the OpenAI API.*

### 2. Using Local Models (Privacy/Offline)
If no `OPENAI_API_KEY` is provided, or the model name doesn't start with `gpt`, the Ghost uses the local runtime. You can pre-pull multiple local models:
```bash
# Pre-pull local brains
GHOST_MODELS_TO_PULL="llama3.1 gemma2 phi3"

# Set active local brain
GHOST_MODEL=llama3.1
```

## Configuration

Key environment variables (set in `.env`):

| Variable | Default | Description |
|---|---|---|
| `GHOST_MODEL` | `gpt-4-turbo` | **Universal Selector.** Active model used by the Ghost. Handles local Ghost runtime models OR cloud models (ChatGPT) if `OPENAI_API_KEY` is set and model starts with `gpt-`. |
| `OPENAI_API_KEY` | - | Required for ChatGPT models. If set, overrides the local runtime for `gpt-*` models. |
| `GHOST_MODELS_TO_PULL` | `llama3.2` | Space-separated list of local models to pre-load on startup. |
| `GHOST_CRON` | `0 2 * * *` | Schedule for recurring analysis (daily at 02:00 UTC) |
| `GHOST_RUN_ON_STARTUP` | `true` | Run an analysis immediately on container start |
| `GHOST_MAX_LOG_LINES` | `2500` | Max log lines sampled per analysis run |
| `GHOST_CONTEXT_CHARS` | `24000` | Max characters of evidence sent to the LLM |
| `GHOST_LOCAL_API` | `http://ghost:11434` | Internal URL for the local reasoning engine. |

## Profile

```bash
# Start The Ghost only
docker compose -f security-stack.compose.yml --profile ghost up -d
```
