# Windows AppLocker

This folder contains the HQSec containment AppLocker script used by Ansible incident-response playbooks.

## Containment Script

`HQSec-Containment-AppLocker.ps1` starts the Application Identity service, creates a default AppLocker policy, sets each rule collection to the requested enforcement mode, merges the policy locally, and exports the resulting XML policy to:

```text
C:\ProgramData\HQSec\Response\applocker-containment.xml
```

Use `AuditOnly` while testing on a target group:

```powershell
.\HQSec-Containment-AppLocker.ps1 -EnforcementMode AuditOnly
```

Validate the generated policy XML without applying it:

```powershell
.\HQSec-Containment-AppLocker.ps1 -EnforcementMode AuditOnly -ValidateOnly
```

Use `Enabled` only after the target is approved for containment:

```powershell
.\HQSec-Containment-AppLocker.ps1 -EnforcementMode Enabled
```

## Ansible Response

The main response playbook is:

```bash
ansible-playbook playbooks/windows-contain-malicious.yml -l endpoint-01 -e soc_subnet=10.77.0.0/24
```

For audit-mode testing:

```bash
ansible-playbook playbooks/windows-applocker-containment.yml -l endpoint-01 -e applocker_mode=AuditOnly
```

AppLocker requires Windows editions that support AppLocker policy enforcement, typically Enterprise, Education, or Server. Hosts that do not support the needed cmdlets will write failure details under `C:\ProgramData\HQSec\Response`.

