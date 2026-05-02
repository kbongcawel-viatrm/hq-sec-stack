# Velociraptor IR Setup

Velociraptor is the endpoint visibility, live query, digital forensics, and threat-hunting layer for `hq-sec-stack`.

## Role

- Run live endpoint queries during active triage.
- Collect scoped forensic evidence from hosts tied to Wazuh, Graylog, Suricata, Sysmon, or PowerShell alerts.
- Launch hunts across multiple endpoints for known indicators or suspicious behavior.
- Return collection IDs, client IDs, observables, and result summaries to TheHive cases.

## Service

Compose service:

```text
velociraptor
```

Endpoints:

```text
GUI:      http://localhost:8889
FQDN:     http://velociraptor.hq-sec.local
Frontend: http://localhost:8000
Internal: http://velociraptor:8889
```

The repo-local Velociraptor folder is mounted read-only inside the container at:

```text
/hq-sec-velociraptor
```

## Operating Flow

1. Start from a TheHive case, Wazuh alert, Graylog query, or Suricata alert.
2. Identify scope: hostname, user, time range, process ID, command line, IP, domain, file path, or hash.
3. Run a live query or a targeted collection from `collections/`.
4. Escalate to a hunt only when the same indicator may exist on multiple endpoints.
5. Attach result summaries, collection IDs, and observables back to TheHive.

## Artifact Packs

Custom artifacts live in:

```text
artifacts/
```

Recommended initial imports:

- `HQSec.Windows.EndpointVisibility`
- `HQSec.Windows.PowerShellTriage`
- `HQSec.Windows.PersistenceAndTamper`

## Safety

Keep collections scoped. Endpoint collection can include sensitive user, browser, file, command, and registry data. Avoid broad filesystem collection unless the case owner approves it.
