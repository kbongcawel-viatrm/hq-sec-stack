# Ansible Incident Response

Ansible is the controlled response executor for flagged malicious activity. Use it only after TheHive records analyst approval or a pre-approved Shuffle workflow decision.

## Inventory

Add approved response targets to `inventory`:

```ini
[windows_targets]
endpoint-01 ansible_host=192.0.2.10 ansible_user=ir
```

WinRM connection defaults are already defined under `[windows_targets:vars]`.

## Contain A Malicious Windows Host

Run the full containment chain:

```bash
ansible-playbook playbooks/windows-contain-malicious.yml -l endpoint-01 -e soc_subnet=10.77.0.0/24
```

The chain performs these actions in order:

1. Collects key Windows event logs into `C:\ProgramData\HQSec\Artifacts.zip`.
2. Applies AppLocker containment using `The Sword/Windows/Applocker/HQSec-Containment-AppLocker.ps1`.
3. Isolates the endpoint by allowing SOC management traffic and setting Windows Firewall profiles to default deny.

Use audit mode before enforcing AppLocker on a new host group:

```bash
ansible-playbook playbooks/windows-contain-malicious.yml -l endpoint-01 -e soc_subnet=10.77.0.0/24 -e applocker_mode=AuditOnly
```

## Individual Actions

Collect evidence only:

```bash
ansible-playbook playbooks/windows-collect-artifacts.yml -l endpoint-01
```

Apply AppLocker containment only:

```bash
ansible-playbook playbooks/windows-applocker-containment.yml -l endpoint-01 -e applocker_mode=Enabled
```

Isolate network access only:

```bash
ansible-playbook playbooks/windows-isolate.yml -l endpoint-01 -e soc_subnet=10.77.0.0/24
```

Stop a suspicious service during isolation:

```bash
ansible-playbook playbooks/windows-isolate.yml -l endpoint-01 -e soc_subnet=10.77.0.0/24 -e suspicious_service=BadService
```

## Case Notes

Attach the following to the TheHive case after execution:

- Ansible command and output.
- Changed host list.
- `C:\ProgramData\HQSec\Response\isolation-started.txt`.
- `C:\ProgramData\HQSec\Response\isolation-completed.txt`.
- `C:\ProgramData\HQSec\Response\applocker-containment.log`.
- `C:\ProgramData\HQSec\Response\applocker-containment.xml`.
