# Velociraptor Endpoint Hunt Plan

Use Velociraptor for:

- Endpoint visibility and live querying
- Digital forensics collection
- Threat hunting across endpoints
- Artifact collection

Initial hunt questions:

1. Which user launched the suspicious PowerShell process?
2. What parent process launched it?
3. Which network connections were opened?
4. Were persistence locations modified?
5. Were suspicious files written to Startup, Temp, or system directories?

Recommended artifacts:

- Windows.Sysinternals.SysmonInstall state
- Windows.EventLogs.EvtxHunter
- Windows.Forensics.Prefetch
- Windows.System.Pslist
- Windows.Network.Netstat
- Windows.Persistence.PowershellProfile
- Windows.Registry.NTUser
