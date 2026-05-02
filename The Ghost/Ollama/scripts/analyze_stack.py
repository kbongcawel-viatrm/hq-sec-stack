#!/usr/bin/env python3
"""
The Ghost — LLM Governance Engine for hq-sec-stack.

The soul behind all body parts. Pulls the strings. Makes everyone better.

  The Eyes   → perceive   (Suricata, Zeek, Caddy access logs, Uptime-Kuma)
  The Brain  → analyze    (Wazuh/OSSEC logs, Graylog API)
  The Shield → harden     (Vault, OpenVAS, Trivy container scans, CrowdSec)
  The Sword  → execute    (Ansible directives, CrowdSec block candidates, Suricata rules)
  The Hands  → support    (CoreDNS, Caddy proxy, backup health, report delivery)
"""

import base64
import json
import os
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path


# ── Output paths (written through The Hands) ──────────────────────────────────
REPORT_DIR     = Path("/reports/log-assessments")
DIRECTIVES_DIR = Path("/reports/ghost-directives")
LATEST_DIR     = REPORT_DIR / "latest"
LATEST_DIRS_D  = DIRECTIVES_DIR / "latest"

# ── Log sources organised by pillar ──────────────────────────────────────────
PILLAR_LOGS = {
    "eyes":   {
        # Primary perception via Graylog/TheHive APIs
    },
    "brain":  {
        "wazuh":    Path("/logs/wazuh-manager"),
    },
    "shield": {
        "vault":    Path("/logs/vault"),
        "openvas":  Path("/logs/openvas"),
    },
    "sword": {
        "suricata": Path("/logs/suricata"),
        "zeek":     Path("/logs/zeek"),
        "crowdsec": Path("/logs/crowdsec"),
    },
    "hands": {
        "caddy":    Path("/logs/caddy"),
    },
}

VULN_REPORT_ROOT = Path("/evidence/container-vulnerabilities/latest")
BACKUP_ROOT      = Path("/backups")

KEYWORDS = (
    "critical", "error", "failed", "failure", "alert",
    "blocked", "denied", "scan", "malware", "exploit",
    "brute", "intrusion", "anomaly", "unauthorized",
)


# ── Helpers ───────────────────────────────────────────────────────────────────
def _env(name, default=""):
    return os.getenv(name, default)


def env_bool(name, default):
    return os.getenv(name, default).lower() == "true"


def env_int(name, default):
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


def utc_today():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


# ── Log evidence collection ───────────────────────────────────────────────────
def iter_recent_lines(root: Path, max_files=20, max_lines=500):
    if not root.exists():
        return
    files = sorted(
        [p for p in root.rglob("*") if p.is_file()],
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    seen = 0
    for path in files[:max_files]:
        try:
            with path.open("r", encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    if seen >= max_lines:
                        return
                    seen += 1
                    yield path, line.rstrip("\n")
        except OSError:
            continue


def collect_log_evidence(max_lines: int) -> dict:
    all_roots = {
        f"{pillar}:{svc}": root
        for pillar, sources in PILLAR_LOGS.items()
        for svc, root in sources.items()
    }
    per_root   = max(80, max_lines // max(1, len(all_roots)))
    logs       = {}
    kw_counts  = Counter()
    high_signal = []

    for label, root in all_roots.items():
        pillar = label.split(":")[0]
        lines  = []
        for path, line in iter_recent_lines(root, max_lines=per_root):
            lines.append(f"{path.name}: {line[:800]}")
            lower = line.lower()
            for kw in KEYWORDS:
                if kw in lower:
                    kw_counts[kw] += 1
            if len(high_signal) < 60 and any(k in lower for k in KEYWORDS[:8]):
                high_signal.append({
                    "pillar":  pillar,
                    "source":  label,
                    "message": line[:500],
                })
        logs[label] = lines[-per_root:]

    # Trivy vulnerability reports (Shield)
    vuln_reports = []
    if VULN_REPORT_ROOT.exists():
        for path in sorted(VULN_REPORT_ROOT.glob("*.json"))[:20]:
            try:
                data = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
                vuln_reports.append({"file": path.name, "summary": str(data)[:1200]})
            except (OSError, json.JSONDecodeError):
                continue

    # Backup health (Hands)
    backup_info = {"available": BACKUP_ROOT.exists(), "latest": None, "count": 0}
    if BACKUP_ROOT.exists():
        dirs = sorted(p for p in BACKUP_ROOT.iterdir() if p.is_dir())
        backup_info["latest"] = dirs[-1].name if dirs else None
        backup_info["count"]  = len(dirs)

    return {
        "logs":          logs,
        "keyword_counts": dict(kw_counts),
        "high_signal":   high_signal,
        "vuln_reports":  vuln_reports,
        "backup_health": backup_info,
    }


# ── API clients ───────────────────────────────────────────────────────────────
def _get_json(url, headers=None, timeout=20):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def _basic_auth_header(user, password):
    token = base64.b64encode(f"{user}:{password}".encode()).decode()
    return {"Authorization": f"Basic {token}"}


def fetch_graylog() -> dict:
    """Brain — pull last 24 h of events from Graylog."""
    api    = _env("GRAYLOG_API_URL", "http://graylog:9000/api").rstrip("/")
    hdrs   = {
        **_basic_auth_header(_env("GRAYLOG_ROOT_USERNAME", "admin"),
                              _env("GRAYLOG_ROOT_PASSWORD", "admin")),
        "Accept":       "application/json",
        "X-Requested-By": "the-ghost",
    }
    params = urllib.parse.urlencode({
        "query": "*", "range": "86400", "limit": "50", "sort": "timestamp:desc",
    })
    try:
        data = _get_json(f"{api}/search/universal/relative?{params}", headers=hdrs)
        return {"source": "graylog", "messages": data.get("messages", [])}
    except Exception as exc:
        return {"source": "graylog", "error": str(exc)}


def fetch_crowdsec() -> dict:
    """Shield/Sword — active decisions and recent alerts from CrowdSec LAPI."""
    base    = _env("CROWDSEC_LAPI_URL", "http://crowdsec:8080").rstrip("/")
    api_key = _env("CROWDSEC_API_KEY", "")
    if not api_key:
        return {"source": "crowdsec", "error": "CROWDSEC_API_KEY not configured"}
    hdrs = {"X-Api-Key": api_key, "Accept": "application/json"}
    result: dict = {"source": "crowdsec"}
    for key, path in (("decisions", "/v1/decisions"), ("alerts", "/v1/alerts?limit=30")):
        try:
            data = _get_json(f"{base}{path}", headers=hdrs)
            result[key] = (data[:50] if isinstance(data, list) else data)
        except Exception as exc:
            result[f"{key}_error"] = str(exc)
    return result


def fetch_uptime_kuma() -> dict:
    """Hands — reachability check for Uptime-Kuma."""
    url = _env("UPTIME_KUMA_URL", "http://uptime-kuma:3001")
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=5) as r:
            return {"source": "uptime-kuma", "reachable": True, "http_status": r.status}
    except Exception as exc:
        return {"source": "uptime-kuma", "reachable": False, "error": str(exc)}


# ── Prompt builder ────────────────────────────────────────────────────────────
def build_prompt(evidence: dict) -> str:
    limit   = env_int("OLLAMA_ANALYSIS_CONTEXT_CHARS", 24000)
    context = json.dumps(evidence, indent=2)[:limit]
    return f"""You are The Ghost — the governing intelligence of the hq-sec-stack security lab.
You are the soul behind all the body parts. You pull the strings. You make everyone better.
Use ONLY the evidence provided. Do not fabricate findings beyond what the data shows.

━━━ YOUR MANDATE PER PILLAR ━━━

THE EYES (Suricata IDS, Zeek, Caddy access logs, Uptime-Kuma)
→ What do The Eyes currently perceive? Find network threats, anomalies, suspicious traffic.
→ What are they missing? Identify detection blind spots and recommend new rules or monitors.

THE BRAIN (Wazuh SIEM, OSSEC, Graylog)
→ What does The Brain know from the aggregated evidence? Correlate alerts, find patterns.
→ What rules need to be added or tuned? Provide Wazuh XML rule snippets and Graylog queries.

THE SHIELD (Vault, OpenVAS, Trivy, CrowdSec, Velociraptor, osquery, TheHive)
→ What is currently exposed or misconfigured based on the evidence?
→ Produce a prioritised hardening checklist. Flag credential, certificate, and CVE risks.

THE SWORD (Ansible, CrowdSec, Suricata custom rules)
→ What threats must be neutralised right now?
→ Produce ready-to-review Ansible task steps, CrowdSec block candidates, and Suricata rule lines.
→ Do NOT claim to execute — these are directives for human review and approval.

THE HANDS (CoreDNS, Caddy FQDN proxy, volume-backup, report dashboard)
→ Is the routing, proxying, and backup infrastructure healthy?
→ Flag any configuration gaps or failures observed in the evidence.

━━━ REQUIRED OUTPUT FORMAT ━━━

## Executive Risk
(LOW / MEDIUM / HIGH / CRITICAL — one-sentence justification)

## Eyes — What We See
(Threats and coverage gaps from network perception)

## Brain — What We Know
(SIEM correlation, alert rule gaps, recommended Graylog queries)

## Shield — What We Harden
(Prioritised hardening actions, CVEs, misconfigs)

## Sword — What We Execute
(Ansible steps, CrowdSec IP blocks, Suricata rule candidates — for human review only)

## Hands — Infrastructure Health
(DNS, proxy, backup, and report delivery status)

## Ghost Directives
(Top 5 cross-pillar actions ranked by impact)

━━━ EVIDENCE ━━━
{context}
"""


# ── Fallback ──────────────────────────────────────────────────────────────────
def fallback_assessment(evidence: dict, error: Exception) -> str:
    has_signals = bool(evidence.get("local", {}).get("high_signal"))
    risk = "MEDIUM" if has_signals else "LOW"
    return "\n".join([
        f"# Ghost Assessment Fallback — {utc_today()}",
        "",
        f"Ollama was unavailable: `{error}`",
        "",
        f"Fallback risk: **{risk}**",
        "",
        "Manual review of Graylog and all log sources required.",
    ])


# ── Output writers ────────────────────────────────────────────────────────────
PILLAR_SECTIONS = {
    "eyes":   "## Eyes — What We See",
    "brain":  "## Brain — What We Know",
    "shield": "## Shield — What We Harden",
    "sword":  "## Sword — What We Execute",
    "hands":  "## Hands — Infrastructure Health",
}

NEXT_SECTION = [
    "## Eyes — What We See",
    "## Brain — What We Know",
    "## Shield — What We Harden",
    "## Sword — What We Execute",
    "## Hands — Infrastructure Health",
    "## Ghost Directives",
]


def extract_section(markdown: str, heading: str) -> str:
    """Extract text between a heading and the next known heading."""
    lines  = markdown.splitlines()
    inside = False
    out    = []
    for line in lines:
        if line.strip() == heading:
            inside = True
            out.append(line)
            continue
        if inside:
            if any(line.strip() == h for h in NEXT_SECTION if h != heading):
                break
            out.append(line)
    return "\n".join(out).strip()


def write_outputs(markdown: str, evidence: dict, model: str):
    now  = datetime.now(timezone.utc).isoformat()
    date = utc_today()

    # Create directories
    dated_dir = REPORT_DIR / date
    dated_d   = DIRECTIVES_DIR / date
    for d in (dated_dir, LATEST_DIR, dated_d, LATEST_DIRS_D):
        d.mkdir(parents=True, exist_ok=True)

    local         = evidence.get("local", {})
    kw_counts     = local.get("keyword_counts", {})
    notable       = local.get("high_signal", [])
    risk          = "low"
    if kw_counts.get("critical") or kw_counts.get("exploit") or len(notable) >= 10:
        risk = "high"
    elif kw_counts.get("error") or kw_counts.get("failed") or notable:
        risk = "medium"

    recommendations = []
    for line in markdown.splitlines():
        s = line.strip()
        if s.startswith("- ") and len(recommendations) < 10:
            recommendations.append(s[2:])
    if not recommendations:
        recommendations.append("Review full Ghost assessment and validate findings in Graylog.")

    summary = {
        "date":            date,
        "generated_at":    now,
        "assessment_type": "ghost-llm-governance",
        "model":           model,
        "risk":            risk,
        "signals":         kw_counts,
        "notable_events":  notable,
        "recommendations": recommendations,
        "markdown":        markdown,
        "evidence_sources": {
            "graylog_available":    "error" not in evidence.get("brain_api", {}).get("graylog", {}),
            "crowdsec_available":   "error" not in evidence.get("shield_api", {}).get("crowdsec", {}),
            "uptime_kuma_reachable": evidence.get("hands_api", {}).get("uptime_kuma", {}).get("reachable", False),
            "log_pillars":          list(local.get("logs", {}).keys()),
            "keyword_counts":       kw_counts,
        },
    }

    # Master assessment
    (dated_dir / "assessment.md").write_text(markdown + "\n", encoding="utf-8")
    (dated_dir / "assessment.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (LATEST_DIR / "assessment.md").write_text(markdown + "\n", encoding="utf-8")
    (LATEST_DIR / "assessment.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    # Per-pillar directive files
    header = f"<!-- Ghost directive — {date} | model: {model} | risk: {risk} -->\n\n"
    for pillar, heading in PILLAR_SECTIONS.items():
        content = extract_section(markdown, heading)
        if not content:
            content = f"{heading}\n\n_No findings for this pillar in this run._"
        text = header + content + "\n"
        (dated_d   / f"{pillar}.md").write_text(text, encoding="utf-8")
        (LATEST_DIRS_D / f"{pillar}.md").write_text(text, encoding="utf-8")

    # Ghost Directives summary file
    directives = extract_section(markdown, "## Ghost Directives")
    (dated_d       / "ghost-directives.md").write_text(header + directives + "\n", encoding="utf-8")
    (LATEST_DIRS_D / "ghost-directives.md").write_text(header + directives + "\n", encoding="utf-8")


# ── Main loop ─────────────────────────────────────────────────────────────────
def run_once():
    max_lines = env_int("OLLAMA_ANALYSIS_MAX_LOG_LINES", 2500)
    model     = _env("OLLAMA_MODEL", "llama3.2")

    evidence = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        # Per-pillar log evidence
        "local":        collect_log_evidence(max_lines),
        # Brain APIs
        "brain_api":    {"graylog": fetch_graylog()},
        # Shield/Sword APIs
        "shield_api":   {"crowdsec": fetch_crowdsec()},
        # Hands APIs
        "hands_api":    {"uptime_kuma": fetch_uptime_kuma()},
    }

    prompt = build_prompt(evidence)
    try:
        base = _env("OLLAMA_URL", "http://ollama:11434").rstrip("/")
        payload = {
            "model":   model,
            "prompt":  prompt,
            "stream":  False,
            "options": {"temperature": 0.2},
        }
        req = urllib.request.Request(
            f"{base}/api/generate",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=300) as r:
            markdown = json.loads(r.read().decode()).get("response", "")
    except Exception as exc:
        markdown = fallback_assessment(evidence, exc)

    write_outputs(markdown, evidence, model)


def seconds_until_next_cron(cron_expr: str) -> int:
    parts = cron_expr.split()
    if len(parts) != 5:
        return 3600
    minute, hour, day, month, weekday = parts
    if day != "*" or month != "*" or weekday != "*":
        return 3600
    now    = datetime.now()
    hours  = range(24) if hour == "*"   else [int(hour)]
    mins   = range(60) if minute == "*" else [int(minute)]
    cands  = []
    for add in range(0, 8):
        base_date = now.date() + timedelta(days=add)
        for h in hours:
            for m in mins:
                c = datetime.combine(base_date, datetime.min.time()).replace(hour=h, minute=m)
                if c > now:
                    cands.append(c)
    return max(60, int((min(cands) - now).total_seconds())) if cands else 3600


def main():
    if env_bool("OLLAMA_ANALYSIS_RUN_ON_STARTUP", "true"):
        run_once()
    if env_bool("OLLAMA_ANALYSIS_ONCE", "false"):
        return
    cron = _env("OLLAMA_ANALYSIS_CRON", "0 2 * * *")
    while True:
        time.sleep(seconds_until_next_cron(cron))
        run_once()


if __name__ == "__main__":
    main()
