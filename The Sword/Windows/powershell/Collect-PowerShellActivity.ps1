[CmdletBinding()]
param(
  [string]$OutputDirectory = "C:\ProgramData\HQSec\PowerShellLogs",
  [int]$LookbackMinutes = 10
)

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outFile = Join-Path $OutputDirectory ("powershell-activity-{0}.jsonl" -f (Get-Date -Format "yyyyMMdd"))
$start = (Get-Date).AddMinutes(-1 * $LookbackMinutes)

$events = Get-WinEvent -FilterHashtable @{
  LogName = "Microsoft-Windows-PowerShell/Operational"
  Id = 4103,4104,400,600
  StartTime = $start
} -ErrorAction SilentlyContinue

foreach ($event in $events) {
  $xml = [xml]$event.ToXml()
  $payload = [ordered]@{
    timestamp = $event.TimeCreated.ToUniversalTime().ToString("o")
    host = $env:COMPUTERNAME
    event_id = $event.Id
    provider = $event.ProviderName
    process_id = $event.ProcessId
    owner = $event.UserId.Value
    command = ($xml.Event.EventData.Data | ForEach-Object { $_.'#text' }) -join " "
    channel = $event.LogName
    record_id = $event.RecordId
  }
  $payload | ConvertTo-Json -Compress | Add-Content -Path $outFile -Encoding UTF8
}
