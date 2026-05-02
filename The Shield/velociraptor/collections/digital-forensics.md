# Digital Forensics Collection

Use this after triage confirms the host needs evidence preservation.

## Scope

Start with time-bounded and path-bounded collections. Avoid broad disk collection until the case owner approves it.

## Recommended Artifacts

- `HQSec.Windows.PowerShellTriage`
- `HQSec.Windows.PersistenceAndTamper`
- `Windows.EventLogs.EvtxHunter`
- `Windows.Forensics.Prefetch`
- `Windows.Registry.NTUser`
- `Windows.Timeline.MFT`
- `Windows.Forensics.Usn`
- `Windows.KapeFiles.Targets`

## Evidence Targets

- PowerShell operational logs
- Security `4688` process creation
- Sysmon operational logs
- PowerShell transcripts in `C:\ProgramData\HQSec\PowerShellLogs`
- fallback collector JSONL files
- Prefetch for suspicious binaries
- persistence registry keys
- Startup and scheduled task paths
- telemetry install paths for Wazuh, OSSEC, Sysmon, and HQSec fallback scripts

## TheHive Notes

Attach or link:

- collection ID
- evidence time range
- collected artifact names
- paths collected
- relevant hashes
- suspicious command lines
- observable list for IPs, domains, hashes, users, and hostnames
