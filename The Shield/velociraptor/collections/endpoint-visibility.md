# Endpoint Visibility Collection

Use this when an alert names a host, user, process, command line, IP, or domain and you need live context quickly.

## Scope

Collect only from the host or small host set named in the case.

## Recommended Artifacts

- `HQSec.Windows.EndpointVisibility`
- `Windows.System.Pslist`
- `Windows.Network.Netstat`
- `Windows.System.Services`
- `Windows.System.TaskScheduler`

## Questions

- Which user is active on the endpoint?
- Which suspicious process is running?
- What parent process launched it?
- Which remote IPs or ports are connected?
- Are Wazuh, OSSEC, Sysmon, EventLog, or PowerShell logging services present and running?

## TheHive Notes

Record:

- Velociraptor client ID
- collection ID
- hostname
- user
- process ID
- parent process ID
- command line
- remote IP and port
- short analyst summary
