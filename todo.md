update README.md and simplify

~~Create the crowdsec and applocker iner configuration files.~~

~~add nmap and wireshark container configuration files.~~

~~Create crowdsec container and configuration files.~~

~~add crowdsec rules to block malicious ip addresses.~~

Ensure Ollama has internal access and connectivity to all other containers but ensure that our services are not publicly available to the internet. Let's maximize use of private routing and private DNS to limit exposure of our infrastructure to the internet.

Ensure our DNS is internal and not exposed to the internet. This is to avoid our DNS from being used to track us.

Setup portainer to monitor our docker environment and containers. This will allow us to monitor containers with GUI. Place this under the category of management tools. Add documentation to the Readme.md file for portainer.

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

7:18 PM
