# Windows Endpoint Detection Flow

1. PowerShell runs on a target Windows host.
2. PowerShell transcription, module, and script block logging capture commands.
3. Sysmon captures process creation, parent process, PID, user, command line, network connections, and file changes.
4. Wazuh/OSSEC agent monitors Windows events, Sysmon logs, PowerShell logs, FIM, registry changes, and suspicious commands.
5. Fluent Bit or Wazuh forwards endpoint telemetry to Graylog and Wazuh.
6. Suricata detects suspicious network traffic from the endpoint.
7. Graylog stores and visualizes PowerShell, Sysmon, FIM, Suricata, and Wazuh alerts.
8. Wazuh applies detection rules and raises alerts.
9. TheHive receives confirmed alerts and manages cases/tasks.
10. Velociraptor performs live querying, forensic collection, and threat hunting.
11. Ansible performs approved response: isolate host, block IPs, stop services, pull artifacts, reapply security config.
