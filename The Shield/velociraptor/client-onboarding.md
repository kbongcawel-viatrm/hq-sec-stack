# Velociraptor Client Onboarding

Use this as the target-host checklist after the Velociraptor server is running.

## Server URLs

Use the frontend URL for client enrollment:

```text
http://<server-ip-or-fqdn>:8000
```

In this stack:

```text
http://velociraptor.hq-sec.local:8000
http://localhost:8000
```

Use the GUI for operators:

```text
http://velociraptor.hq-sec.local
http://localhost:8889
```

## Client Labels

Apply labels consistently so hunts can target a small group:

- `windows`
- `linux`
- `server`
- `workstation`
- `domain-controller`
- `high-value`
- `lab`
- `suspected-compromise`

## Enrollment Workflow

1. Start the `velociraptor` service.
2. Log into the GUI.
3. Generate the client package for the target operating system.
4. Install the client on authorized target hosts.
5. Confirm the client appears online.
6. Add host labels.
7. Run `HQSec.Windows.EndpointVisibility` on one test endpoint.
8. Record the client ID and hostname in the asset inventory or TheHive case.

## Minimum Endpoint Coverage

For Windows hosts, confirm the endpoint also has:

- Sysmon installed with `The Sword/Windows/sysmon/sysmon-hq-sec.xml`.
- PowerShell script block logging and transcription enabled.
- The HQSec PowerShell fallback scheduled task installed.
- Wazuh or OSSEC agent installed where applicable.

Velociraptor should not replace those logs. It should collect and validate them during investigation.
