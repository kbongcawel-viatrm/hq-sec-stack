$ErrorActionPreference = "Stop"

$wslScript = "/opt/ossec-server/scripts/run-ossec-daily-logs.sh"
$dateStamp = Get-Date -Format "MMddyyyy"
$runTs = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")

& wsl --cd /opt/ossec-server -d CBL-Mariner -u root --exec /usr/bin/sh -c "chmod 755 '$wslScript' && DATE_STAMP='$dateStamp' RUN_TS='$runTs' '$wslScript'"

& "D:\codex-workspace\Copy-OssecLogs.ps1"
