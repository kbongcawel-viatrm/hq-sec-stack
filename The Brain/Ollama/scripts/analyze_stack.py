#!/usr/bin/env python3
import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path


REPORT_DIR = Path("/reports/log-assessments")
LATEST_DIR = REPORT_DIR / "latest"
LOG_ROOTS = {
    "suricata": Path("/logs/suricata"),
    "zeek": Path("/logs/zeek"),
    "wazuh-manager": Path("/logs/wazuh-manager"),
    "vault": Path("/logs/vault"),
    "openvas": Path("/logs/openvas"),
}
VULN_REPORT_ROOT = Path("/evidence/container-vulnerabilities/latest")


def env_bool(name, default):
    return os.getenv(name, default).lower() == "true"


def utc_today():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def iter_recent_lines(root: Path, max_files=20, max_lines=500):
    if not root.exists():
        return
    files = [p for p in root.rglob("*") if p.is_file()]
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    seen = 0
    for path in files[:max_files]:
        try:
            with path.open("r", encoding="utf-8", errors="ignore") as handle:
                for line in handle:
                    if seen >= max_lines:
                        return
                    seen += 1
                    yield path, line.rstrip("\n")
        except OSError:
            continue


def read_local_evidence(max_lines):
    evidence = {}
    keyword_counts = Counter()
    high_signal = []
    per_root_lines = max(100, max_lines // max(1, len(LOG_ROOTS)))
    keywords = ("critical", "error", "failed", "failure", "alert", "blocked", "denied", "scan", "malware", "exploit")

    for service, root in LOG_ROOTS.items():
        lines = []
        for path, line in iter_recent_lines(root, max_lines=per_root_lines):
            lines.append(f"{path.name}: {line[:800]}")
            lower = line.lower()
            for keyword in keywords:
                if keyword in lower:
                    keyword_counts[keyword] += 1
            if len(high_signal) < 40 and any(k in lower for k in keywords[:6]):
                high_signal.append({"source": service, "file": str(path), "message": line[:500]})
        evidence[service] = lines[-per_root_lines:]

    vuln_summaries = []
    if VULN_REPORT_ROOT.exists():
        for path in sorted(VULN_REPORT_ROOT.glob("*.json"))[:20]:
            try:
                data = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
                vuln_summaries.append({"file": path.name, "summary": str(data)[:1200]})
            except (OSError, json.JSONDecodeError):
                continue

    return {
        "local_logs": evidence,
        "keyword_counts": dict(keyword_counts),
        "high_signal_events": high_signal,
        "container_vulnerability_reports": vuln_summaries,
    }


def graylog_request(path):
    api_url = os.getenv("GRAYLOG_API_URL", "http://graylog:9000/api").rstrip("/")
    username = os.getenv("GRAYLOG_ROOT_USERNAME", "admin")
    password = os.getenv("GRAYLOG_ROOT_PASSWORD", "admin")
    url = f"{api_url}{path}"
    req = urllib.request.Request(url)
    token = base64.b64encode(f"{username}:{password}".encode()).decode()
    req.add_header("Authorization", f"Basic {token}")
    req.add_header("Accept", "application/json")
    req.add_header("X-Requested-By", "ollama-assessor")
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.loads(response.read().decode())


def read_graylog_evidence():
    query = urllib.parse.urlencode({
        "query": "*",
        "range": "86400",
        "limit": "50",
        "sort": "timestamp:desc",
    })
    try:
        return {
            "source": "graylog",
            "messages": graylog_request(f"/search/universal/relative?{query}").get("messages", []),
        }
    except Exception as exc:
        return {"source": "graylog", "error": str(exc)}


def call_ollama(prompt):
    base_url = os.getenv("OLLAMA_URL", "http://ollama:11434").rstrip("/")
    model = os.getenv("OLLAMA_MODEL", "llama3.2")
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.2},
    }
    req = urllib.request.Request(
        f"{base_url}/api/generate",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=300) as response:
        return json.loads(response.read().decode()).get("response", "")


def build_prompt(evidence):
    context_limit = int(os.getenv("OLLAMA_ANALYSIS_CONTEXT_CHARS", "24000"))
    context = json.dumps(evidence, indent=2)[:context_limit]
    return f"""You are the local SOC LLM for hq-sec-stack.

Use only the evidence provided. Do not claim live detection beyond this sample.

Foundations:
1. Brain: analyze aggregated logs with Graylog as primary source.
2. Eyes: determine attack patterns from Suricata, Zeek, OSSEC/Wazuh, and network evidence.
3. Shield: improve hardening using Vault, vault-rotator, osquery, TheHive, Shuffle, Velociraptor, Ansible, OpenVAS, and Trivy evidence.
4. Sword: plan response and protection actions, especially Ansible playbook ideas, but do not execute actions.

Return concise Markdown with these sections:
- Executive Risk
- Key Evidence
- Suspected Attack Patterns
- Hardening Recommendations
- Incident Response Plan
- Ansible Playbook Ideas
- Follow-Up Queries For Graylog

Evidence JSON:
{context}
"""


def fallback_assessment(evidence, error):
    risk = "medium" if evidence.get("local", {}).get("high_signal_events") else "low"
    return "\n".join([
        f"# Ollama Assessment Fallback - {utc_today()}",
        "",
        f"Ollama analysis was unavailable: `{error}`.",
        "",
        f"Fallback risk: **{risk.upper()}**",
        "",
        "Review Graylog and the sampled local log evidence manually.",
    ])


def write_outputs(markdown, evidence, model):
    now = datetime.now(timezone.utc).isoformat()
    date = utc_today()
    out_dir = REPORT_DIR / date
    out_dir.mkdir(parents=True, exist_ok=True)
    LATEST_DIR.mkdir(parents=True, exist_ok=True)

    local = evidence.get("local", {})
    local_logs = local.get("local_logs", {})
    services = {
        service: {
            "lines_sampled": len(lines),
            "files_sampled": None,
            "signals": {},
        }
        for service, lines in local_logs.items()
    }
    keyword_counts = local.get("keyword_counts", {})
    notable_events = local.get("high_signal_events", [])
    risk = "low"
    if keyword_counts.get("critical") or keyword_counts.get("exploit") or len(notable_events) >= 10:
        risk = "high"
    elif keyword_counts.get("error") or keyword_counts.get("failed") or notable_events:
        risk = "medium"

    recommendations = []
    for line in markdown.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ") and len(recommendations) < 8:
            recommendations.append(stripped[2:])
    if not recommendations:
        recommendations.append("Review the Ollama Markdown assessment and validate findings in Graylog before action.")

    summary = {
        "date": date,
        "generated_at": now,
        "assessment_type": "ollama-llm-analysis",
        "model": model,
        "risk": risk,
        "signals": keyword_counts,
        "services": services,
        "notable_events": notable_events,
        "assessment": markdown.splitlines()[0] if markdown.splitlines() else "Ollama assessment generated.",
        "recommendations": recommendations,
        "markdown": markdown,
        "evidence_summary": {
            "graylog_available": "error" not in evidence.get("graylog", {}),
            "local_sources": list(evidence.get("local", {}).get("local_logs", {}).keys()),
            "keyword_counts": evidence.get("local", {}).get("keyword_counts", {}),
        },
    }

    md_path = out_dir / "assessment.md"
    json_path = out_dir / "assessment.json"
    md_path.write_text(markdown + "\n", encoding="utf-8")
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (LATEST_DIR / "assessment.md").write_text(md_path.read_text(encoding="utf-8"), encoding="utf-8")
    (LATEST_DIR / "assessment.json").write_text(json_path.read_text(encoding="utf-8"), encoding="utf-8")


def run_once():
    max_lines = int(os.getenv("OLLAMA_ANALYSIS_MAX_LOG_LINES", "2500"))
    evidence = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "graylog": read_graylog_evidence(),
        "local": read_local_evidence(max_lines),
    }
    model = os.getenv("OLLAMA_MODEL", "llama3.2")
    prompt = build_prompt(evidence)
    try:
        markdown = call_ollama(prompt)
    except Exception as exc:
        markdown = fallback_assessment(evidence, exc)
    write_outputs(markdown, evidence, model)


def seconds_until_next_cron(cron_expr):
    parts = cron_expr.split()
    if len(parts) != 5:
        return 3600
    minute, hour, day, month, weekday = parts
    if day != "*" or month != "*" or weekday != "*":
        return 3600
    now = datetime.now()
    minutes = range(60) if minute == "*" else [int(minute)]
    hours = range(24) if hour == "*" else [int(hour)]
    candidates = []
    for add_days in range(0, 8):
        base = now.date() + timedelta(days=add_days)
        for h in hours:
            for m in minutes:
                candidate = datetime.combine(base, datetime.min.time()).replace(hour=h, minute=m)
                if candidate > now:
                    candidates.append(candidate)
    if not candidates:
        return 3600
    return max(60, int((min(candidates) - now).total_seconds()))


def main():
    if env_bool("OLLAMA_ANALYSIS_RUN_ON_STARTUP", "true"):
        run_once()
    if env_bool("OLLAMA_ANALYSIS_ONCE", "false"):
        return
    cron = os.getenv("OLLAMA_ANALYSIS_CRON", "0 2 * * *")
    while True:
        time.sleep(seconds_until_next_cron(cron))
        run_once()


if __name__ == "__main__":
    main()
