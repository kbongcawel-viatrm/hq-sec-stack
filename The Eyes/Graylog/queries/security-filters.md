# Graylog Security Queries

PowerShell commands:

```text
source:* AND (powershell OR pwsh OR winlog_event_id:4104 OR winlog_event_id:4103)
```

Suspicious PowerShell:

```text
(powershell OR pwsh) AND ("-enc" OR "EncodedCommand" OR "DownloadString" OR "Invoke-Expression" OR "FromBase64String" OR "bypass")
```

Sysmon process creation:

```text
winlog_channel:"Microsoft-Windows-Sysmon/Operational" AND winlog_event_id:1
```

FIM/syscheck changes:

```text
(rule_groups:syscheck OR syscheck OR fim OR "File modified" OR "Integrity checksum changed")
```

Registry persistence:

```text
("\\CurrentVersion\\Run" OR "\\RunOnce" OR "\\Winlogon\\Shell" OR "Image File Execution Options")
```

Suricata alerts:

```text
alert.signature:* OR event_type:alert OR suricata.eve
```

Suspicious network activities:

```text
(event_type:alert OR zeek.log OR suricata.eve) AND (scan OR exploit OR malware OR trojan OR c2 OR beacon)
```

Wazuh high severity:

```text
rule_level:>=10 OR level:>=10 OR "Suspicious PowerShell" OR "Critical Windows file integrity change"
```
