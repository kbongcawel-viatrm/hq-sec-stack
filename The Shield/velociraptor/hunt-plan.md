# Velociraptor Endpoint Hunt Plan

Velociraptor provides endpoint visibility, live querying, forensic collection, and threat hunting for the stack.

## Entry Points

Use Velociraptor after one of these signals appears:

- Wazuh high-severity alert
- Graylog PowerShell, FIM, or network query hit
- Suricata suspicious network alert
- Sysmon process, file, registry, DNS, or network event
- TheHive case task requesting endpoint evidence
- PowerShell fallback collector alert after an agent was removed

## Initial Hunt Questions

1. Which user launched the suspicious process?
2. What parent process launched it?
3. Which command line or script block ran?
4. Which network connections or DNS queries followed?
5. Were persistence locations modified?
6. Were scripts or binaries written to Startup, Temp, user profile, or system directories?
7. Were Wazuh, OSSEC, Sysmon, EventLog, PowerShell logging, or HQSec fallback files tampered with?
8. Did the same indicator appear on other endpoints?

## Collection Tiers

### Tier 1: Live Endpoint Visibility

Use when the alert is still fresh and the host may be active.

- `HQSec.Windows.EndpointVisibility`
- `Windows.System.Pslist`
- `Windows.Network.Netstat`
- `Windows.System.Services`
- `Windows.System.TaskScheduler`

### Tier 2: PowerShell And Process Triage

Use for suspicious PowerShell, script block logging, transcript, or fallback collector alerts.

- `HQSec.Windows.PowerShellTriage`
- `Windows.EventLogs.EvtxHunter`
- `Windows.Forensics.Prefetch`
- `Windows.Persistence.PowershellProfile`

### Tier 3: Persistence And Telemetry Tamper

Use when the alert suggests agent removal, logging bypass, service control, autoruns, registry changes, or scheduled tasks.

- `HQSec.Windows.PersistenceAndTamper`
- `Windows.Registry.NTUser`
- `Windows.System.Services`
- `Windows.System.TaskScheduler`
- `Windows.Sysinternals.Autoruns`

### Tier 4: Broader Forensics

Use only after the case owner approves broader collection.

- `Windows.Timeline.MFT`
- `Windows.Forensics.Usn`
- `Windows.KapeFiles.Targets`
- targeted file collection by path or hash

## TheHive Case Updates

Every Velociraptor action should add these case notes:

- Velociraptor client ID
- collection or hunt ID
- hostname
- user
- time range
- artifact names
- observables found
- result summary
- recommended next action

## Response Handoff

Velociraptor collects and confirms evidence. Shuffle and Ansible perform repeatable response only after approval, such as host isolation, file collection, service stop, or IP blocking.
