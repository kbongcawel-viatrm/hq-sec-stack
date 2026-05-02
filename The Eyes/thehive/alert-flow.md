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

Velociraptor task detail:

```text
Run HQSec.Windows.EndpointVisibility for live process, network, service, user, and scheduled-task context.
Run HQSec.Windows.PowerShellTriage for PowerShell, Sysmon, Security 4688, transcript, and fallback collector evidence.
Run HQSec.Windows.PersistenceAndTamper if the alert suggests service removal, logging bypass, autoruns, registry persistence, or scheduled task tampering.
Record the Velociraptor client ID, collection ID, artifact names, time range, and result summary back into this case.
```
