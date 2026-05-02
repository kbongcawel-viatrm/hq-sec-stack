# Ollama Analysis Runtime

Ollama is the local LLM runtime for stack assessment, report generation, attack-pattern review, hardening recommendations, and response planning.

## Containers

| Container | Role |
| --- | --- |
| `ollama` | Runs the `ollama/ollama` API on port `11434` |
| `ollama-model-pull` | Pulls `${OLLAMA_MODEL:-llama3.2}` after the API is healthy |
| `ollama-assessor` | Scheduled log and evidence analysis task |

## Endpoints

| Endpoint | Purpose |
| --- | --- |
| `http://localhost:11434` | Host API access |
| `http://ollama.hq-sec.local` | Local FQDN API route |
| `http://ollama:11434` | Internal Docker API |

Use `/api/generate` or `/api/chat` for contextual analysis. The model does not persist new knowledge across sessions. Historical context requires a future RAG pipeline or explicit evidence supplied in each prompt.

## Model

Default model:

```text
OLLAMA_MODEL=llama3.2
```

`gemma3` can be used instead if the deployment host has enough resources and the model is available through Ollama.

## Schedule

`ollama-assessor` runs on startup and then according to:

```text
OLLAMA_ANALYSIS_CRON=0 2 * * *
```

The cron implementation supports simple daily/hourly expressions with `minute hour * * *`. Reports are written to:

```text
The Hands/reports/data/log-assessments/latest/assessment.md
The Hands/reports/data/log-assessments/latest/assessment.json
```

## Evidence Sources

- Graylog API as the primary log source.
- Suricata and Zeek log volumes for network visibility.
- Wazuh manager logs for endpoint and OSSEC activity.
- Vault and vault-rotator logs for secrets hygiene.
- OpenVAS logs and Trivy reports for hardening context.
- TheHive, Shuffle, Velociraptor, and Ansible context for incident response planning.

## Security Notes

The lab Ollama API is internal but not authenticated by default. Bind host access with `STACK_BIND_IP` and keep `ollama.hq-sec.local` on the local lab network. The assessor uses Graylog credentials from `.env` or `.env.vault`; those credentials are already covered by the Vault secret manifest and monthly rotation workflow.

Ollama runs with the upstream image default user because model storage under `/root/.ollama` is the image's standard path. Treat the model volume as persistent state and include it in backups.

## Persona Foundations

Brain: analyze aggregated logs from Graylog and local service volumes.

Eyes: determine attack patterns from Suricata, Zeek, OSSEC/Wazuh, and network evidence.

Shield: recommend hardening using Vault, osquery, Greenbone/OpenVAS, TheHive, Shuffle, Velociraptor, and Ansible context.

Sword: plan protective execution, including Ansible playbook ideas, without executing response actions automatically.

