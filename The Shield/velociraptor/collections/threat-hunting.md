# Threat Hunting Across Endpoints

Use this when one indicator may exist on multiple endpoints.

## Hunt Seeds

Start from confirmed indicators in Wazuh, Graylog, Suricata, Sysmon, or TheHive:

- suspicious command text
- script block text
- process name
- parent process
- file path
- hash
- IP address
- domain
- registry key
- service name
- scheduled task name

## Recommended Artifacts

- `HQSec.Windows.EndpointVisibility`
- `HQSec.Windows.PowerShellTriage`
- `HQSec.Windows.PersistenceAndTamper`
- `Windows.Search.FileFinder`
- `Windows.EventLogs.EvtxHunter`
- `Windows.System.Pslist`
- `Windows.Network.Netstat`

## Hunt Patterns

PowerShell download cradle:

```text
downloadstring|invoke-webrequest|invoke-restmethod|frombase64string|encodedcommand
```

Telemetry tamper:

```text
wazuh|ossec|sysmon|eventlog|stop-service|remove-service|sc stop|sc delete
```

Persistence:

```text
CurrentVersion\Run|RunOnce|Winlogon\Shell|Image File Execution Options|Startup|Scheduled Tasks
```

Suspicious script extensions:

```text
.ps1|.psm1|.vbs|.js|.jse|.hta|.bat|.cmd
```

## Escalation

If a hunt returns hits on multiple endpoints:

1. Create or update a TheHive case.
2. Add hostnames, users, IPs, domains, file paths, and hashes as observables.
3. Run targeted forensic collection on confirmed hosts.
4. Hand containment to Ansible or Shuffle only after approval.
