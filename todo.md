2. Create powershell logging scripts using task scheduler to log and flag powershell ran logs/commands. It should gather the process, processID, owner, and the commands ran. We should create a script that runs and if powershell is used, it will send it to graylog. It should be able to log everything including powershell commands that are run. This is for the case that the agent is removed.
3. Create Wazuh configuration rules needed for detection, file integrity checking, and alerting. It should be able to detect powershell commands that are run in the event that the agent is removed.
4. Create Graylog regex queries to easily filter flagged logs e.g. logged powershell commands, syscheck, file integrity changes, and suspicious network activities.
5. Sysmon configuration to get who ran the flagged activities and how. This is for the case that the agent is removed.
6. Suricata configuration for IDS.
7. The hive for: Case management, Alert ingestion, Task assignment & tracking
8. Velociraptor
   Endpoint visibility & live querying
   Digital forensics collection
   Threat hunting across endpoints
   9.Fluent Bit = collects, parses, filters, and forwards logs
   Graylog = stores, searches, visualizes, alerts, and correlates logs
   10 Ansible creates ansible playbooks to be triggered as response to flagged malicious attacks: - Isolate instance by removing its network connectivity.

The flow should be:

1. PowerShell runs on target Windows host

- PowerShell Logging captures commands.
- Sysmon captures process details: parent process, PID, user, command line.

2. OSSEC/Wazuh agent monitors host activity

- File integrity changes
- Registry changes
- Suspicious Windows events
- Sysmon logs
- PowerShell logs

3. Suricata monitors network traffic
   - Detects suspicious outbound/inbound traffic
   - Sends IDS alerts to Graylog/Wazuh
4. Fluent Bit collects and forwards logs
   - Windows logs
   - Sysmon logs
   - PowerShell logs
   - Suricata logs
   - OSSEC/Wazuh logs if needed
5. Graylog stores, searches, visualizes, and dashboards logs

- PowerShell activity
- Sysmon activity
- Syscheck/FIM changes
- Suricata alerts
- Wazuh alerts

6. Wazuh detects and alerts

- File tampering
- Registry tampering
- Suspicious PowerShell
- Suspicious process chains
- Compliance/hardening findings

7. TheHive receives confirmed alerts

- Case management
- Alert ingestion
- Task assignment
- Investigation tracking

8. Velociraptor investigates endpoints

- Live query
- Forensic collection
- Threat hunting
- Artifact collection

9. Ansible performs response actions

- Isolate host
- Disable network interface
- Block IP using Windows Firewall
- Stop suspicious service
  Pull logs/artifacts
- Reapply security config

10. Endpoint response actions happen

- Defender scan/quarantine
- AppLocker enforcement
- Backup/restore if needed

update .gitignore to exclude files that have sensitive information
7:18 PM

update README.md and simplify

Create the crowdstrike, fail2ban, and Applocker container configuration files.

add nmap and wireshark container configuration files.

Create crowdsec container and configuration files.

add crowdsec rules to block malicious ip addresses.
