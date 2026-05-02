import json
import os
from collections import Counter
from datetime import datetime, timezone
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
KEYWORDS = {
    "critical": ("critical", "crit", "panic", "fatal"),
    "error": ("error", "err", "exception", "failed", "failure"),
    "warning": ("warning", "warn", "denied", "blocked"),
    "auth": ("login", "auth", "password", "token", "credential"),
    "network": ("suricata", "zeek", "scan", "connection", "dns", "tls"),
}


def utc_today():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def iter_recent_lines(root: Path, max_files=20, max_lines=5000):
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


def assess():
    today = utc_today()
    now = datetime.now(timezone.utc).isoformat()
    service_stats = {}
    global_counts = Counter()
    notable = []

    for service, root in LOG_ROOTS.items():
        counts = Counter()
        line_count = 0
        files = set()
        for path, line in iter_recent_lines(root):
            line_count += 1
            files.add(str(path))
            lower = line.lower()
            for bucket, words in KEYWORDS.items():
                if any(word in lower for word in words):
                    counts[bucket] += 1
                    global_counts[bucket] += 1
            if len(notable) < 25 and any(word in lower for word in KEYWORDS["critical"] + KEYWORDS["error"]):
                notable.append({"service": service, "file": str(path), "message": line[:500]})

        service_stats[service] = {
            "lines_sampled": line_count,
            "files_sampled": len(files),
            "signals": dict(counts),
        }

    risk = "low"
    if global_counts["critical"] or global_counts["error"] >= 25:
        risk = "high"
    elif global_counts["error"] or global_counts["warning"] >= 25:
        risk = "medium"

    recommendations = []
    if global_counts["critical"] or global_counts["error"]:
        recommendations.append("Review notable error lines and correlate them in Graylog by source and service.")
    if service_stats.get("suricata", {}).get("lines_sampled", 0) == 0:
        recommendations.append("Confirm Suricata is writing eve.json and the sensor interface is receiving traffic.")
    if service_stats.get("zeek", {}).get("lines_sampled", 0) == 0:
        recommendations.append("Confirm Zeek is writing logs and the sensor interface is receiving traffic.")
    if not recommendations:
        recommendations.append("No high-signal local log issues found in the sampled files; continue monitoring Graylog streams.")

    summary = {
        "date": today,
        "generated_at": now,
        "assessment_type": "local-ai-rule-summary",
        "risk": risk,
        "signals": dict(global_counts),
        "services": service_stats,
        "notable_events": notable,
        "assessment": (
            f"Today's local AI assessment rates the stack risk as {risk}. "
            f"Sampled log files produced {sum(global_counts.values())} keyword-based signals. "
            "Use Graylog for full-fidelity search and this report as a quick triage layer."
        ),
        "recommendations": recommendations,
    }
    return summary


def write_outputs(summary):
    date = summary["date"]
    out_dir = REPORT_DIR / date
    out_dir.mkdir(parents=True, exist_ok=True)
    LATEST_DIR.parent.mkdir(parents=True, exist_ok=True)

    json_path = out_dir / "assessment.json"
    md_path = out_dir / "assessment.md"
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    lines = [
        f"# Daily Log Assessment - {date}",
        "",
        f"Generated: `{summary['generated_at']}`",
        f"Risk: **{summary['risk'].upper()}**",
        "",
        summary["assessment"],
        "",
        "## Signals",
        "",
    ]
    for key, value in sorted(summary["signals"].items()):
        lines.append(f"- `{key}`: {value}")
    lines.extend(["", "## Recommendations", ""])
    for item in summary["recommendations"]:
        lines.append(f"- {item}")
    lines.extend(["", "## Notable Events", ""])
    for event in summary["notable_events"][:10]:
        lines.append(f"- `{event['service']}` `{event['file']}`: {event['message']}")
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    latest_json = LATEST_DIR / "assessment.json"
    latest_md = LATEST_DIR / "assessment.md"
    LATEST_DIR.mkdir(exist_ok=True)
    latest_json.write_text(json_path.read_text(encoding="utf-8"), encoding="utf-8")
    latest_md.write_text(md_path.read_text(encoding="utf-8"), encoding="utf-8")


def main():
    run_on_startup = os.getenv("LOG_ASSESSMENT_RUN_ON_STARTUP", "true").lower() == "true"
    interval = int(os.getenv("LOG_ASSESSMENT_INTERVAL_SECONDS", "3600"))
    once = os.getenv("LOG_ASSESSMENT_ONCE", "false").lower() == "true"

    if run_on_startup:
        write_outputs(assess())
    if once:
        return

    import time

    while True:
        time.sleep(interval)
        write_outputs(assess())


if __name__ == "__main__":
    main()
