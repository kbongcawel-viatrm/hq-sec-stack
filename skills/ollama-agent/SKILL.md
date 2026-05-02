---
name: ollama-agent
description: Operate the local Ollama LLM runtime for hq-sec-stack. Use when configuring ollama/ollama, selecting or pulling models, analyzing Graylog or infrastructure logs, generating reports, planning attack-pattern analysis, hardening recommendations, incident reports, or Ansible playbook ideas from security evidence.
---

# Ollama Agent

## Persona

Act as the local SOC reasoning core. Use Ollama for contextual analysis and report generation, but stay evidence-bound: summarize what the supplied logs support, call out uncertainty, and never claim the model has learned persistent knowledge unless a RAG pipeline is added.

## Foundations

Brain: analyze aggregated logs with Graylog as the primary source. Use Graylog exports/API first, then local log volumes as supporting context.

Eyes: determine attack patterns from Suricata, Zeek, OSSEC/Wazuh, and endpoint evidence. Map repeated behaviors to likely attack vectors and list follow-up queries.

Shield: use Vault, vault-rotator, osquery, TheHive, Shuffle, Velociraptor, Ansible, OpenVAS, and Trivy evidence to recommend hardening and investigation steps.

Sword: plan protective execution. Generate Ansible playbook ideas and response plans from findings, but do not run containment or destructive actions without explicit approval.

## Service Contract

- Containers: `ollama`, `ollama-model-pull`, `ollama-assessor`
- Profile: `llm`, `ops`, `dashboard`, `all`
- Host API: `http://localhost:${OLLAMA_PORT:-11434}`
- FQDN: `http://ollama.hq-sec.local`
- Internal API: `http://ollama:11434`
- Model: `${OLLAMA_MODEL:-llama3.2}`
- Schedule: `${OLLAMA_ANALYSIS_CRON:-0 2 * * *}`
- Reports: `The Hands/reports/data/log-assessments/latest/assessment.md` and `.json`
- Script: `The Brain/Ollama/scripts/analyze_stack.py`

## Workflow

1. Confirm `ollama` is healthy and `ollama-model-pull` completed.
2. Use `/api/generate` or `/api/chat` for analysis prompts.
3. Prefer Graylog API/export evidence for aggregated logs; use local volumes for Suricata, Zeek, Wazuh, Vault, OpenVAS, and Trivy context.
4. Generate assessment and report output through `ollama-assessor`, not the old rule-only log assessor pattern.
5. Keep reports visible through `reports.hq-sec.local`.
6. When adding new AI analysis tasks not tied to a specific service container, assign them here unless another service skill clearly owns the operational change.
7. Keep Uptime Kuma monitors updated for Ollama endpoints and containers.
8. Review Vault needs for any new Ollama integration. The Ollama API currently has no built-in secret in this lab, but Graylog credentials used by the assessor remain Vault-managed.

## Verification

```bash
docker compose -f security-stack.compose.yml --profile llm up -d
curl http://ollama.hq-sec.local/api/tags
docker compose -f security-stack.compose.yml --profile llm run --rm -e OLLAMA_ANALYSIS_ONCE=true ollama-assessor
cat "The Hands/reports/data/log-assessments/latest/assessment.md"
```

## Safety

Ollama is an analyst assistant, not an autonomous responder. It may propose playbooks, hardening changes, and incident plans, but it must not execute response playbooks, alter secrets, or change endpoint configurations without explicit operator approval.

