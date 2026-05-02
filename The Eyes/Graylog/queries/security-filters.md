# Graylog Security Queries

These searches are meant for Graylog's search bar. Field names can vary slightly depending on whether the event arrived from Wazuh, GELF, Syslog, Fluent Bit, Suricata, Zeek, or the PowerShell fallback collector, so each query includes common field names plus message-text fallbacks.

## PowerShell Activity

All logged PowerShell command activity:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task OR source_type:powershell_eventlog OR source_type:powershell_transcript OR source_type:security_process_creation OR source_type:sysmon_process_creation OR winlog_channel:"Microsoft-Windows-PowerShell/Operational" OR winlog_event_id:4103 OR winlog_event_id:4104 OR winlog_event_id:4688 OR winlog_event_id:1) AND (powershell OR pwsh OR _command:/.*(?i)(powershell|pwsh).*/ OR command:/.*(?i)(powershell|pwsh).*/ OR script_block_text:*)
```

PowerShell script block logging events:

```text
(winlog_event_id:4104 OR event_id:4104 OR _event_id:4104 OR script_block_text:* OR _script_block_text:*) AND (winlog_channel:"Microsoft-Windows-PowerShell/Operational" OR channel:"Microsoft-Windows-PowerShell/Operational" OR provider:/.*(?i)powershell.*/)
```

PowerShell module logging events:

```text
(winlog_event_id:4103 OR event_id:4103 OR _event_id:4103 OR module_name:* OR _module_name:* OR command_name:* OR _command_name:*) AND (powershell OR pwsh OR provider:/.*(?i)powershell.*/)
```

PowerShell transcript fallback events:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task) AND (source_type:powershell_transcript OR _source_type:powershell_transcript OR transcript_path:* OR _transcript_path:*)
```

Suspicious PowerShell commands:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task OR powershell OR pwsh OR script_block_text:* OR _script_block_text:* OR command:* OR _command:*) AND (command:/.*(?i)(-enc|-encodedcommand|downloadstring|invoke-webrequest|\biwr\b|\biex\b|invoke-expression|frombase64string|reflection\.assembly|amsiutils|bypass|hidden|nop|add-mppreference|set-mppreference).*/ OR _command:/.*(?i)(-enc|-encodedcommand|downloadstring|invoke-webrequest|\biwr\b|\biex\b|invoke-expression|frombase64string|reflection\.assembly|amsiutils|bypass|hidden|nop|add-mppreference|set-mppreference).*/ OR script_block_text:/.*(?i)(downloadstring|invoke-expression|frombase64string|amsiutils|add-mppreference|set-mppreference).*/ OR message:/.*(?i)(-enc|-encodedcommand|downloadstring|invoke-expression|frombase64string|amsiutils|bypass|hidden|nop).*/)
```

Fallback collector flagged events:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task) AND (_suspicious:1 OR suspicious:1 OR _suspicious:true OR suspicious:true OR _suspicious_reasons:* OR suspicious_reasons:*)
```

PowerShell process creation with owner and PID fields present:

```text
(source_type:security_process_creation OR source_type:sysmon_process_creation OR winlog_event_id:4688 OR winlog_event_id:1) AND (image:/.*(?i)\\(powershell|pwsh)\.exe$/ OR _image:/.*(?i)\\(powershell|pwsh)\.exe$/ OR winlog_event_data_Image:/.*(?i)\\(powershell|pwsh)\.exe$/ OR winlog_event_data_NewProcessName:/.*(?i)\\(powershell|pwsh)\.exe$/) AND (process_id:* OR _process_id:* OR winlog_event_data_ProcessId:* OR owner:* OR _owner:* OR winlog_event_data_User:*)
```

## Wazuh Alerts

High-severity Wazuh alerts:

```text
(rule_level:>=10 OR level:>=10 OR _event_id:/1001(00|02|09|10|11|12|13|22|23)/ OR rule_id:/1001(00|02|09|10|11|12|13|22|23)/) OR message:/.*(?i)(suspicious powershell|critical windows file integrity|telemetry service|fallback collector detected).*/
```

Wazuh PowerShell detection rules:

```text
(rule_id:100099 OR rule_id:100100 OR rule_id:100101 OR rule_id:100108 OR rule_id:100109 OR rule_id:100120 OR rule_id:100121 OR rule_id:100122 OR rule_id:100124 OR _event_id:100099 OR _event_id:100100 OR _event_id:100101 OR _event_id:100108 OR _event_id:100109 OR _event_id:100120 OR _event_id:100121 OR _event_id:100122 OR _event_id:100124) OR message:/.*(?i)(powershell process|powershell script block|fallback powershell|powershell transcript).*/
```

Telemetry tampering and agent removal attempts:

```text
(rule_id:100110 OR rule_id:100111 OR rule_id:100112 OR rule_id:100113 OR rule_id:100123 OR _event_id:100110 OR _event_id:100111 OR _event_id:100112 OR _event_id:100113 OR _event_id:100123) OR message:/.*(?i)(stop|delete|disable|remove-service|stop-service|set-service).*(wazuh|ossec|sysmon|eventlog|hqsec-powershell-command-audit).*/
```

## File Integrity Monitoring

All syscheck or FIM events:

```text
(rule_groups:syscheck OR rule_groups:fim OR decoder_name:syscheck OR syscheck:* OR fim:* OR file:* OR path:* OR message:/.*(?i)(syscheck|file integrity|integrity checksum|file modified|file added|file deleted).*/)
```

Critical Windows FIM changes:

```text
(rule_id:100102 OR _event_id:100102 OR file:/.*(?i)(\\Windows\\System32\\drivers\\etc\\hosts$|\\Windows\\System32\\config\\SAM$|\\Windows\\System32\\config\\SYSTEM$|\\Windows\\System32\\config\\SECURITY$|\\Windows\\System32\\GroupPolicy\\|\\Windows\\System32\\Tasks\\|\\Start Menu\\Programs\\Startup\\|\\ProgramData\\HQSec\\PowerShellLogs\\).*/ OR message:/.*(?i)(hosts|SAM|SYSTEM|SECURITY|GroupPolicy|Startup|PowerShellLogs).*)
```

Monitoring tool or fallback collector FIM changes:

```text
(rule_id:100111 OR _event_id:100111 OR file:/.*(?i)(\\Program Files(?: \(x86\))?\\ossec-agent\\|\\Program Files(?: \(x86\))?\\Wazuh\\|\\Program Files\\Sysmon\\|\\ProgramData\\HQSec\\PowerShellLogs\\Collect-PowerShellActivity\.ps1$).*/ OR message:/.*(?i)(ossec-agent|wazuh|sysmon|Collect-PowerShellActivity\.ps1).*)
```

Registry persistence or security-control changes:

```text
(rule_id:100103 OR _event_id:100103 OR winlog_event_data_TargetObject:/.*(?i)(\\Run\\|\\RunOnce\\|\\Winlogon\\Shell|\\Image File Execution Options\\|\\Services\\|\\Windows Defender\\Exclusions\\).*/ OR targetObject:/.*(?i)(\\Run\\|\\RunOnce\\|\\Winlogon\\Shell|\\Image File Execution Options\\|\\Services\\|\\Windows Defender\\Exclusions\\).*/ OR message:/.*(?i)(CurrentVersion\\Run|RunOnce|Winlogon\\Shell|Image File Execution Options|Windows Defender\\Exclusions).*)
```

## Network Activity

All Suricata alerts:

```text
(event_type:alert OR alert.signature:* OR alert_signature:* OR suricata.eve:* OR source:suricata OR gl2_source_input:*suricata*)
```

Suspicious Suricata network activity:

```text
(event_type:alert OR alert.signature:* OR alert_signature:* OR suricata.eve:* OR source:suricata) AND (alert.signature:/.*(?i)(c2|command and control|malware|trojan|exploit|scan|beacon|botnet|ransomware).*/ OR alert_signature:/.*(?i)(c2|command and control|malware|trojan|exploit|scan|beacon|botnet|ransomware).*/ OR message:/.*(?i)(c2|command and control|malware|trojan|exploit|scan|beacon|botnet|ransomware).*/)
```

PowerShell or LOLBin network connections:

```text
(winlog_event_id:3 OR event_id:3 OR _event_id:3 OR source_type:sysmon_network_connection OR message:/.*(?i)network connection.*/) AND (image:/.*(?i)\\(powershell|pwsh|cmd|mshta|rundll32|regsvr32)\.exe$/ OR _image:/.*(?i)\\(powershell|pwsh|cmd|mshta|rundll32|regsvr32)\.exe$/ OR winlog_event_data_Image:/.*(?i)\\(powershell|pwsh|cmd|mshta|rundll32|regsvr32)\.exe$/ OR message:/.*(?i)(powershell|pwsh|mshta|rundll32|regsvr32).*/)
```

Potential scanning or exploit traffic from Suricata or Zeek:

```text
(event_type:alert OR alert.signature:* OR zeek.log:* OR source:zeek OR source:suricata OR message:/.*(?i)(zeek|suricata).*/) AND (message:/.*(?i)(scan|exploit|bruteforce|brute force|suspicious inbound|suspicious outbound|recon|nmap|masscan).*/ OR alert.signature:/.*(?i)(scan|exploit|recon|nmap|masscan).*/ OR alert_signature:/.*(?i)(scan|exploit|recon|nmap|masscan).*/)
```

## Quick Triage

Last-mile incident triage across endpoint, FIM, and network alerts:

```text
(_suspicious:1 OR suspicious:1 OR rule_level:>=10 OR level:>=10 OR rule_groups:syscheck OR event_type:alert OR alert.signature:* OR message:/.*(?i)(suspicious powershell|critical windows file integrity|command and control|malware|trojan|exploit|agent removed|service stopped|fallback collector).*/)
```

Events from a specific host:

```text
(host:"HOSTNAME" OR source:"HOSTNAME" OR agent_name:"HOSTNAME" OR winlog_computer_name:"HOSTNAME") AND (_suspicious:1 OR suspicious:1 OR powershell OR syscheck OR event_type:alert OR alert.signature:*)
```
