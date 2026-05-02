# TheHive Case Flow

Use TheHive for:

- Case management
- Alert ingestion
- Task assignment and tracking
- Investigation history

Recommended alert payload fields:

```json
{
  "title": "Suspicious PowerShell activity",
  "type": "wazuh",
  "source": "wazuh-manager",
  "sourceRef": "<alert-id>",
  "severity": 3,
  "tags": ["powershell", "sysmon", "hq-sec-stack"],
  "description": "Suspicious command line detected. Review Graylog query and Wazuh alert.",
  "observables": [
    {"dataType": "hostname", "data": "<endpoint>"},
    {"dataType": "user", "data": "<owner>"},
    {"dataType": "ip", "data": "<source-ip>"}
  ]
}
```

Default tasks:

1. Validate alert in Graylog and Wazuh.
2. Collect endpoint triage with Velociraptor.
3. Decide containment.
4. Run approved Ansible response.
5. Document recovery and lessons learned.
