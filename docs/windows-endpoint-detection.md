# Windows Endpoint Detection Flow

1. PowerShell runs on a target Windows host.
2. PowerShell transcription, module, and script block logging capture commands.
3. Sysmon captures process creation, parent process, parent PID, process PID, user, command line, hashes, network connections, DNS queries, file creates/deletes, alternate data streams, image loads, registry changes, and Sysmon errors.
4. Wazuh/OSSEC agent monitors Windows events, Sysmon logs, PowerShell logs, FIM, registry changes, and suspicious commands.
5. Fluent Bit or Wazuh forwards endpoint telemetry to Graylog and Wazuh.
6. Suricata detects suspicious network traffic from the endpoint.
7. Graylog stores and visualizes PowerShell, Sysmon, FIM, Suricata, and Wazuh alerts.
8. Wazuh applies detection rules and raises alerts.
9. TheHive receives confirmed alerts and manages cases/tasks.
10. Velociraptor performs live querying, forensic collection, and threat hunting.
11. Ansible performs approved response: collect artifacts, apply AppLocker containment, isolate the host to the SOC subnet, stop suspicious services, and preserve response markers for TheHive.

## PowerShell Logging Fallback

The Windows PowerShell scheduled-task collector is a fallback path for cases where the Wazuh/OSSEC agent is removed or disabled. It enables Windows PowerShell and PowerShell Core script block logging, module logging, transcription with invocation headers, and Windows process creation auditing, then runs every minute as `SYSTEM`.

Install it from an elevated PowerShell prompt on the Windows endpoint:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "The Sword\Windows\powershell\Install-PowerShellLoggingTask.ps1" -GraylogHost "127.0.0.1" -GraylogGelfUdpPort 12201 -WazuhSyslogHost "127.0.0.1" -WazuhSyslogUdpPort 1516
```

The scheduled task writes local JSONL evidence under `C:\ProgramData\HQSec\PowerShellLogs`, sends GELF UDP events directly to Graylog, and sends JSON syslog fallback events to Wazuh. Events include the host, event source, process ID, parent process ID when available, owner, command line, script block text, script block ID, script path, module and command names, transcript path, transcript offset, image path, parent image, and suspicious-command flags.

The fallback collector also reads `Microsoft-Windows-Sysmon/Operational` directly. That means Sysmon process creation, network connection, DNS, file, registry, image-load, and delete events can still be forwarded to Graylog and Wazuh even if the normal endpoint agent is removed.

Wazuh fallback detection uses:

- `The Brain/Wazuh/rules/local_rules.xml` for PowerShell, FIM, telemetry tamper, and fallback collector alerts.
- `The Brain/Wazuh/decoders/local_decoder.xml` to decode `hqsec_powershell_fallback:` JSON syslog events.
- `The Brain/Wazuh/manager/powershell-fallback-syslog.xml` as the manager-side `1516/udp` syslog listener snippet.
