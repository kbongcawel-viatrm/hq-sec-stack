# Graylog Security Queries

These searches are meant for Graylog's search bar. Graylog search uses Lucene-like syntax: regex filters use `/regex/`, boolean operators are uppercase, and field names vary depending on whether data arrived from Wazuh, GELF, Syslog, Fluent Bit, Suricata, Zeek, or the PowerShell fallback collector.

## PowerShell Activity

All logged PowerShell command activity:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task OR source_type:powershell_eventlog OR source_type:powershell_transcript OR source_type:security_process_creation OR source_type:sysmon_process_creation OR winlog_channel:"Microsoft-Windows-PowerShell/Operational" OR winlog_event_id:4103 OR winlog_event_id:4104 OR winlog_event_id:4688 OR winlog_event_id:1) AND (powershell OR pwsh OR _command:/.*([Pp]ower[Ss]hell|pwsh).*/ OR command:/.*([Pp]ower[Ss]hell|pwsh).*/ OR script_block_text:*)
```

PowerShell script block logging events:

```text
(winlog_event_id:4104 OR event_id:4104 OR _event_id:4104 OR script_block_text:* OR _script_block_text:*) AND (winlog_channel:"Microsoft-Windows-PowerShell/Operational" OR channel:"Microsoft-Windows-PowerShell/Operational" OR provider:/.*([Pp]ower[Ss]hell).*/)
```

PowerShell module logging events:

```text
(winlog_event_id:4103 OR event_id:4103 OR _event_id:4103 OR module_name:* OR _module_name:* OR command_name:* OR _command_name:*) AND (powershell OR pwsh OR provider:/.*([Pp]ower[Ss]hell).*/)
```

PowerShell transcript fallback events:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task) AND (source_type:powershell_transcript OR _source_type:powershell_transcript OR transcript_path:* OR _transcript_path:*)
```

Suspicious PowerShell commands:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task OR powershell OR pwsh OR script_block_text:* OR _script_block_text:* OR command:* OR _command:*) AND (command:/.*(-enc|-encodedcommand|-EncodedCommand|DownloadString|downloadstring|Invoke-WebRequest|invoke-webrequest|iwr|IWR|iex|IEX|Invoke-Expression|invoke-expression|FromBase64String|frombase64string|Reflection\.Assembly|reflection\.assembly|AmsiUtils|amsiutils|bypass|Bypass|hidden|Hidden|nop|NOP|Add-MpPreference|Set-MpPreference).*/ OR _command:/.*(-enc|-encodedcommand|-EncodedCommand|DownloadString|downloadstring|Invoke-WebRequest|invoke-webrequest|iwr|IWR|iex|IEX|Invoke-Expression|invoke-expression|FromBase64String|frombase64string|Reflection\.Assembly|reflection\.assembly|AmsiUtils|amsiutils|bypass|Bypass|hidden|Hidden|nop|NOP|Add-MpPreference|Set-MpPreference).*/ OR script_block_text:/.*(DownloadString|downloadstring|Invoke-Expression|invoke-expression|FromBase64String|frombase64string|AmsiUtils|amsiutils|Add-MpPreference|Set-MpPreference).*/ OR message:/.*(-enc|-encodedcommand|-EncodedCommand|DownloadString|downloadstring|Invoke-Expression|invoke-expression|FromBase64String|frombase64string|AmsiUtils|amsiutils|bypass|Bypass|hidden|Hidden|nop|NOP).*/)
```

Fallback collector flagged events:

```text
(_collector:hq-sec-powershell-task OR collector:hq-sec-powershell-task) AND (_suspicious:1 OR suspicious:1 OR _suspicious:true OR suspicious:true OR _suspicious_reasons:* OR suspicious_reasons:*)
```

PowerShell process creation with owner and PID fields present:

```text
(source_type:security_process_creation OR source_type:sysmon_process_creation OR winlog_event_id:4688 OR winlog_event_id:1) AND (image:/.*\\([Pp]ower[Ss]hell|pwsh)\.exe/ OR _image:/.*\\([Pp]ower[Ss]hell|pwsh)\.exe/ OR winlog_event_data_Image:/.*\\([Pp]ower[Ss]hell|pwsh)\.exe/ OR winlog_event_data_NewProcessName:/.*\\([Pp]ower[Ss]hell|pwsh)\.exe/) AND (process_id:* OR _process_id:* OR winlog_event_data_ProcessId:* OR owner:* OR _owner:* OR winlog_event_data_User:*)
```

## Wazuh Alerts

High-severity Wazuh alerts:

```text
(rule_level:>=10 OR level:>=10 OR _event_id:/1001(00|02|09|10|11|12|13|22|23)/ OR rule_id:/1001(00|02|09|10|11|12|13|22|23)/) OR message:/.*([Ss]uspicious [Pp]ower[Ss]hell|[Cc]ritical [Ww]indows [Ff]ile [Ii]ntegrity|[Tt]elemetry [Ss]ervice|[Ff]allback [Cc]ollector [Dd]etected).*/
```

Wazuh PowerShell detection rules:

```text
(rule_id:100099 OR rule_id:100100 OR rule_id:100101 OR rule_id:100108 OR rule_id:100109 OR rule_id:100120 OR rule_id:100121 OR rule_id:100122 OR rule_id:100124 OR _event_id:100099 OR _event_id:100100 OR _event_id:100101 OR _event_id:100108 OR _event_id:100109 OR _event_id:100120 OR _event_id:100121 OR _event_id:100122 OR _event_id:100124) OR message:/.*([Pp]ower[Ss]hell [Pp]rocess|[Pp]ower[Ss]hell [Ss]cript [Bb]lock|[Ff]allback [Pp]ower[Ss]hell|[Pp]ower[Ss]hell [Tt]ranscript).*/
```

Telemetry tampering and agent removal attempts:

```text
(rule_id:100110 OR rule_id:100111 OR rule_id:100112 OR rule_id:100113 OR rule_id:100123 OR _event_id:100110 OR _event_id:100111 OR _event_id:100112 OR _event_id:100113 OR _event_id:100123) OR message:/.*(stop|Stop|delete|Delete|disable|Disable|remove-service|Remove-Service|stop-service|Stop-Service|set-service|Set-Service).*(wazuh|Wazuh|ossec|OSSEC|sysmon|Sysmon|eventlog|EventLog|HQSec-PowerShell-Command-Audit|hqsec-powershell-command-audit).*/
```

## File Integrity Monitoring

All syscheck or FIM events:

```text
(rule_groups:syscheck OR rule_groups:fim OR decoder_name:syscheck OR syscheck:* OR fim:* OR file:* OR path:* OR message:/.*([Ss]yscheck|[Ff]ile [Ii]ntegrity|[Ii]ntegrity [Cc]hecksum|[Ff]ile [Mm]odified|[Ff]ile [Aa]dded|[Ff]ile [Dd]eleted).*/)
```

Critical Windows FIM changes:

```text
(rule_id:100102 OR _event_id:100102 OR file:/.*(\\Windows\\System32\\drivers\\etc\\hosts|\\Windows\\System32\\config\\SAM|\\Windows\\System32\\config\\SYSTEM|\\Windows\\System32\\config\\SECURITY|\\Windows\\System32\\GroupPolicy\\|\\Windows\\System32\\Tasks\\|\\Start Menu\\Programs\\Startup\\|\\ProgramData\\HQSec\\PowerShellLogs\\).*/ OR message:/.*(hosts|SAM|SYSTEM|SECURITY|GroupPolicy|Startup|PowerShellLogs).*/)
```

Monitoring tool or fallback collector FIM changes:

```text
(rule_id:100111 OR _event_id:100111 OR file:/.*(\\Program Files.*\\ossec-agent\\|\\Program Files.*\\Wazuh\\|\\Program Files\\Sysmon\\|\\ProgramData\\HQSec\\PowerShellLogs\\Collect-PowerShellActivity\.ps1).*/ OR message:/.*(ossec-agent|OSSEC|Wazuh|wazuh|Sysmon|sysmon|Collect-PowerShellActivity\.ps1).*/)
```

Registry persistence or security-control changes:

```text
(rule_id:100103 OR _event_id:100103 OR winlog_event_data_TargetObject:/.*(\\Run\\|\\RunOnce\\|\\Winlogon\\Shell|\\Image File Execution Options\\|\\Services\\|\\Windows Defender\\Exclusions\\).*/ OR targetObject:/.*(\\Run\\|\\RunOnce\\|\\Winlogon\\Shell|\\Image File Execution Options\\|\\Services\\|\\Windows Defender\\Exclusions\\).*/ OR message:/.*(CurrentVersion\\Run|RunOnce|Winlogon\\Shell|Image File Execution Options|Windows Defender\\Exclusions).*/)
```

## Network Activity

All Suricata alerts:

```text
(event_type:alert OR alert.signature:* OR alert_signature:* OR suricata.eve:* OR source:suricata OR gl2_source_input:*suricata*)
```

Suspicious Suricata network activity:

```text
(event_type:alert OR alert.signature:* OR alert_signature:* OR suricata.eve:* OR source:suricata) AND (alert.signature:/.*(C2|c2|command and control|Command and Control|malware|Malware|trojan|Trojan|exploit|Exploit|scan|Scan|beacon|Beacon|botnet|Botnet|ransomware|Ransomware).*/ OR alert_signature:/.*(C2|c2|command and control|Command and Control|malware|Malware|trojan|Trojan|exploit|Exploit|scan|Scan|beacon|Beacon|botnet|Botnet|ransomware|Ransomware).*/ OR message:/.*(C2|c2|command and control|Command and Control|malware|Malware|trojan|Trojan|exploit|Exploit|scan|Scan|beacon|Beacon|botnet|Botnet|ransomware|Ransomware).*/)
```

PowerShell or LOLBin network connections:

```text
(winlog_event_id:3 OR event_id:3 OR _event_id:3 OR source_type:sysmon_network_connection OR message:/.*[Nn]etwork [Cc]onnection.*/) AND (image:/.*\\([Pp]ower[Ss]hell|pwsh|cmd|mshta|rundll32|regsvr32)\.exe/ OR _image:/.*\\([Pp]ower[Ss]hell|pwsh|cmd|mshta|rundll32|regsvr32)\.exe/ OR winlog_event_data_Image:/.*\\([Pp]ower[Ss]hell|pwsh|cmd|mshta|rundll32|regsvr32)\.exe/ OR message:/.*([Pp]ower[Ss]hell|pwsh|mshta|rundll32|regsvr32).*/)
```

Potential scanning or exploit traffic from Suricata or Zeek:

```text
(event_type:alert OR alert.signature:* OR zeek.log:* OR source:zeek OR source:suricata OR message:/.*([Zz]eek|[Ss]uricata).*/) AND (message:/.*(scan|Scan|exploit|Exploit|bruteforce|Bruteforce|brute force|Brute Force|suspicious inbound|Suspicious Inbound|suspicious outbound|Suspicious Outbound|recon|Recon|nmap|Nmap|masscan|Masscan).*/ OR alert.signature:/.*(scan|Scan|exploit|Exploit|recon|Recon|nmap|Nmap|masscan|Masscan).*/ OR alert_signature:/.*(scan|Scan|exploit|Exploit|recon|Recon|nmap|Nmap|masscan|Masscan).*/)
```

## Quick Triage

Last-mile incident triage across endpoint, FIM, and network alerts:

```text
(_suspicious:1 OR suspicious:1 OR rule_level:>=10 OR level:>=10 OR rule_groups:syscheck OR event_type:alert OR alert.signature:* OR message:/.*([Ss]uspicious [Pp]ower[Ss]hell|[Cc]ritical [Ww]indows [Ff]ile [Ii]ntegrity|command and control|Command and Control|malware|Malware|trojan|Trojan|exploit|Exploit|agent removed|Agent Removed|service stopped|Service Stopped|fallback collector|Fallback Collector).*/)
```

Events from a specific host:

```text
(host:"HOSTNAME" OR source:"HOSTNAME" OR agent_name:"HOSTNAME" OR winlog_computer_name:"HOSTNAME") AND (_suspicious:1 OR suspicious:1 OR powershell OR PowerShell OR syscheck OR event_type:alert OR alert.signature:*)
```
