[CmdletBinding()]
param(
  [string]$OutputDirectory = "C:\ProgramData\HQSec\PowerShellLogs",
  [string]$StateDirectory = "C:\ProgramData\HQSec\PowerShellLogs\state",
  [int]$LookbackMinutes = 10,
  [string]$GraylogHost = "127.0.0.1",
  [int]$GraylogGelfUdpPort = 12201,
  [string]$WazuhSyslogHost = "127.0.0.1",
  [int]$WazuhSyslogUdpPort = 1516,
  [switch]$NoGraylogSend,
  [switch]$NoWazuhSend
)

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $StateDirectory | Out-Null
$outFile = Join-Path $OutputDirectory ("powershell-activity-{0}.jsonl" -f (Get-Date -Format "yyyyMMdd"))
$start = (Get-Date).AddMinutes(-1 * $LookbackMinutes)
$collectorRunId = [guid]::NewGuid().ToString()

function Get-StatePath {
  param([string]$Name)
  $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
  Join-Path $StateDirectory "$safeName.state"
}

function Get-LastRecordId {
  param([string]$Name)
  $path = Get-StatePath -Name $Name
  if (Test-Path $path) {
    $value = Get-Content -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($value -match '^\d+$') {
      return [int64]$value
    }
  }
  return 0
}

function Set-LastRecordId {
  param(
    [string]$Name,
    [int64]$RecordId
  )
  $path = Get-StatePath -Name $Name
  Set-Content -Path $path -Value $RecordId -Encoding ASCII
}

function Convert-SidToName {
  param([System.Security.Principal.SecurityIdentifier]$Sid)
  if (-not $Sid) {
    return $null
  }

  try {
    return $Sid.Translate([System.Security.Principal.NTAccount]).Value
  } catch {
    return $Sid.Value
  }
}

function Get-EventDataMap {
  param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
  $xml = [xml]$Event.ToXml()
  $map = @{}
  foreach ($data in $xml.Event.EventData.Data) {
    $name = $data.Name
    if ([string]::IsNullOrWhiteSpace($name)) {
      continue
    }
    $map[$name] = $data.'#text'
  }
  return $map
}

function Get-Suspicion {
  param([string]$Command)

  $indicators = @(
    @{ Name = "encoded_command"; Pattern = '(?i)(-|/)(enc|encodedcommand)\b' },
    @{ Name = "download_cradle"; Pattern = '(?i)downloadstring|invoke-webrequest|iwr\b|curl\b|wget\b|net\.webclient' },
    @{ Name = "inline_execution"; Pattern = '(?i)\biex\b|invoke-expression' },
    @{ Name = "execution_policy_bypass"; Pattern = '(?i)bypass|unrestricted|remotesigned' },
    @{ Name = "hidden_window"; Pattern = '(?i)(-|/)w(indowstyle)?\s+hidden|hidden' },
    @{ Name = "base64_or_reflection"; Pattern = '(?i)frombase64string|reflection\.assembly|amsiutils' },
    @{ Name = "defender_tamper"; Pattern = '(?i)add-mppreference|set-mppreference|disableantispyware|exclusionpath' }
  )

  $reasons = @()
  foreach ($indicator in $indicators) {
    if ($Command -match $indicator.Pattern) {
      $reasons += $indicator.Name
    }
  }

  [ordered]@{
    suspicious = ($reasons.Count -gt 0)
    reasons = $reasons
  }
}

function Get-FirstValue {
  param(
    [hashtable]$Map,
    [string[]]$Names
  )

  foreach ($name in $Names) {
    if ($Map.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace($Map[$name])) {
      return $Map[$name]
    }
  }

  return $null
}

function Split-TextChunk {
  param(
    [string]$Text,
    [int]$MaxLength = 6000
  )

  if ([string]::IsNullOrEmpty($Text)) {
    return @()
  }

  $chunks = @()
  for ($offset = 0; $offset -lt $Text.Length; $offset += $MaxLength) {
    $length = [Math]::Min($MaxLength, $Text.Length - $offset)
    $chunks += $Text.Substring($offset, $length)
  }

  return $chunks
}

function Send-GelfMessage {
  param([hashtable]$Payload)

  if ($NoGraylogSend) {
    return
  }

  foreach ($key in @($Payload.Keys)) {
    if ($null -eq $Payload[$key]) {
      $Payload.Remove($key)
    }
  }

  $json = $Payload | ConvertTo-Json -Compress -Depth 8
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

  if ($bytes.Length -gt 8192) {
    $Payload.short_message = $Payload.short_message.Substring(0, [Math]::Min(900, $Payload.short_message.Length))
    if ($Payload.ContainsKey("_command")) {
      $Payload._command = $Payload._command.Substring(0, [Math]::Min(6000, $Payload._command.Length))
    }
    $json = $Payload | ConvertTo-Json -Compress -Depth 8
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  }

  $udp = New-Object System.Net.Sockets.UdpClient
  try {
    [void]$udp.Send($bytes, $bytes.Length, $GraylogHost, $GraylogGelfUdpPort)
  } finally {
    $udp.Close()
  }
}

function Send-WazuhSyslogMessage {
  param([System.Collections.IDictionary]$Activity)

  if ($NoWazuhSend) {
    return
  }

  $wazuhPayload = [ordered]@{
    collector = "hq-sec-powershell-task"
    collector_run_id = $collectorRunId
    timestamp = $Activity.timestamp
    host = $Activity.host
    source_type = $Activity.source_type
    event_id = $Activity.event_id
    provider = $Activity.provider
    channel = $Activity.channel
    record_id = $Activity.record_id
    process_id = $Activity.process_id
    parent_process_id = $Activity.parent_process_id
    owner = $Activity.owner
    command = $Activity.command
    script_block_text = $Activity.script_block_text
    script_block_id = $Activity.script_block_id
    script_path = $Activity.script_path
    message_number = $Activity.message_number
    message_total = $Activity.message_total
    command_name = $Activity.command_name
    module_name = $Activity.module_name
    context_info = $Activity.context_info
    host_application = $Activity.host_application
    transcript_path = $Activity.transcript_path
    transcript_offset = $Activity.transcript_offset
    image = $Activity.image
    parent_image = $Activity.parent_image
    suspicious = if ($Activity.suspicious) { 1 } else { 0 }
    suspicious_reasons = (($Activity.suspicious_reasons | Where-Object { $_ }) -join ",")
  }

  foreach ($key in @($wazuhPayload.Keys)) {
    if ($null -eq $wazuhPayload[$key]) {
      $wazuhPayload.Remove($key)
    }
  }

  $json = $wazuhPayload | ConvertTo-Json -Compress -Depth 8
  $line = "hqsec_powershell_fallback: $json"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
  $udp = New-Object System.Net.Sockets.UdpClient
  try {
    [void]$udp.Send($bytes, $bytes.Length, $WazuhSyslogHost, $WazuhSyslogUdpPort)
  } finally {
    $udp.Close()
  }
}

function Write-Activity {
  param([System.Collections.IDictionary]$Activity)

  $Activity | ConvertTo-Json -Compress -Depth 8 | Add-Content -Path $outFile -Encoding UTF8

  $level = if ($Activity.suspicious) { 4 } else { 6 }
  $shortMessage = if ($Activity.command) {
    "PowerShell activity: $($Activity.command)"
  } else {
    "PowerShell activity event $($Activity.event_id)"
  }

  $gelf = @{
    version = "1.1"
    host = $Activity.host
    short_message = $shortMessage
    timestamp = [DateTimeOffset]::Parse($Activity.timestamp).ToUnixTimeSeconds()
    level = $level
    _collector = "hq-sec-powershell-task"
    _collector_run_id = $collectorRunId
    _event_id = $Activity.event_id
    _provider = $Activity.provider
    _channel = $Activity.channel
    _record_id = $Activity.record_id
    _process_id = $Activity.process_id
    _parent_process_id = $Activity.parent_process_id
    _owner = $Activity.owner
    _command = $Activity.command
    _script_block_text = $Activity.script_block_text
    _script_block_id = $Activity.script_block_id
    _script_path = $Activity.script_path
    _message_number = $Activity.message_number
    _message_total = $Activity.message_total
    _command_name = $Activity.command_name
    _module_name = $Activity.module_name
    _context_info = $Activity.context_info
    _host_application = $Activity.host_application
    _transcript_path = $Activity.transcript_path
    _transcript_offset = $Activity.transcript_offset
    _image = $Activity.image
    _parent_image = $Activity.parent_image
    _suspicious = if ($Activity.suspicious) { 1 } else { 0 }
    _suspicious_reasons = (($Activity.suspicious_reasons | Where-Object { $_ }) -join ",")
  }

  Send-GelfMessage -Payload $gelf
  Send-WazuhSyslogMessage -Activity $Activity
}

function Read-TranscriptBatch {
  $transcriptFiles = Get-ChildItem -Path $OutputDirectory -Filter "*.txt" -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^PowerShell_transcript\.' } |
    Sort-Object FullName

  foreach ($file in $transcriptFiles) {
    $stateName = "transcript_$($file.FullName)"
    $lastOffset = Get-LastRecordId -Name $stateName
    if ($file.Length -le $lastOffset) {
      continue
    }

    $stream = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
      [void]$stream.Seek($lastOffset, [System.IO.SeekOrigin]::Begin)
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
      $newText = $reader.ReadToEnd()
    } finally {
      $stream.Close()
    }

    $newOffset = $file.Length
    Set-LastRecordId -Name $stateName -RecordId $newOffset

    foreach ($chunk in (Split-TextChunk -Text $newText)) {
      if ([string]::IsNullOrWhiteSpace($chunk)) {
        continue
      }

      $suspicion = Get-Suspicion -Command $chunk
      $payload = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        host = $env:COMPUTERNAME
        source_type = "powershell_transcript"
        event_id = 0
        provider = "PowerShell-Transcript"
        process_id = $PID
        parent_process_id = $null
        owner = $env:USERNAME
        command = $chunk
        script_block_text = $null
        script_block_id = $null
        script_path = $null
        message_number = $null
        message_total = $null
        command_name = $null
        module_name = $null
        context_info = $null
        host_application = $null
        transcript_path = $file.FullName
        transcript_offset = $lastOffset
        image = "transcript"
        parent_image = $null
        channel = "PowerShell-Transcript"
        record_id = $newOffset
        suspicious = $suspicion.suspicious
        suspicious_reasons = $suspicion.reasons
      }
      Write-Activity -Activity $payload
    }
  }
}

function Read-EventLogBatch {
  param(
    [string]$LogName,
    [int[]]$Ids
  )

  $lastRecordId = Get-LastRecordId -Name $LogName
  try {
    $events = Get-WinEvent -FilterHashtable @{
      LogName = $LogName
      Id = $Ids
      StartTime = $start
    } -ErrorAction Stop | Sort-Object RecordId
  } catch {
    return
  }

  $maxRecordId = $lastRecordId
  foreach ($event in $events) {
    if ($event.RecordId -le $lastRecordId) {
      continue
    }

    Write-Output $event
    if ($event.RecordId -gt $maxRecordId) {
      $maxRecordId = $event.RecordId
    }
  }

  if ($maxRecordId -gt $lastRecordId) {
    Set-LastRecordId -Name $LogName -RecordId $maxRecordId
  }
}

$powerShellEvents = Read-EventLogBatch -LogName "Microsoft-Windows-PowerShell/Operational" -Ids @(4103, 4104, 400, 600)

foreach ($event in $powerShellEvents) {
  $data = Get-EventDataMap -Event $event
  $scriptBlockText = Get-FirstValue -Map $data -Names @("ScriptBlockText")
  $contextInfo = Get-FirstValue -Map $data -Names @("ContextInfo")
  $payloadText = Get-FirstValue -Map $data -Names @("Payload")
  $hostApplication = Get-FirstValue -Map $data -Names @("HostApplication")
  $command = Get-FirstValue -Map $data -Names @("ScriptBlockText", "Payload", "ContextInfo", "CommandLine", "HostApplication")
  if ([string]::IsNullOrWhiteSpace($command)) {
    $command = ($data.Values | Where-Object { $_ }) -join " "
  }
  $suspicion = Get-Suspicion -Command $command
  $payload = [ordered]@{
    timestamp = $event.TimeCreated.ToUniversalTime().ToString("o")
    host = $env:COMPUTERNAME
    source_type = "powershell_eventlog"
    event_id = $event.Id
    provider = $event.ProviderName
    process_id = $event.ProcessId
    parent_process_id = $null
    owner = Convert-SidToName -Sid $event.UserId
    command = $command
    script_block_text = $scriptBlockText
    script_block_id = Get-FirstValue -Map $data -Names @("ScriptBlockId")
    script_path = Get-FirstValue -Map $data -Names @("Path")
    message_number = Get-FirstValue -Map $data -Names @("MessageNumber")
    message_total = Get-FirstValue -Map $data -Names @("MessageTotal")
    command_name = Get-FirstValue -Map $data -Names @("CommandName")
    module_name = Get-FirstValue -Map $data -Names @("ModuleName")
    context_info = if ($contextInfo) { $contextInfo } else { $payloadText }
    host_application = $hostApplication
    transcript_path = $null
    transcript_offset = $null
    image = "powershell"
    parent_image = $null
    channel = $event.LogName
    record_id = $event.RecordId
    suspicious = $suspicion.suspicious
    suspicious_reasons = $suspicion.reasons
  }
  Write-Activity -Activity $payload
}

$securityEvents = Read-EventLogBatch -LogName "Security" -Ids @(4688)

foreach ($event in $securityEvents) {
  $data = Get-EventDataMap -Event $event
  $image = $data["NewProcessName"]
  if ($image -notmatch '(?i)\\powershell\.exe$|\\pwsh\.exe$') {
    continue
  }

  $command = $data["CommandLine"]
  $owner = if ($data["SubjectDomainName"]) {
    "$($data["SubjectDomainName"])\$($data["SubjectUserName"])"
  } else {
    $data["SubjectUserName"]
  }
  $suspicion = Get-Suspicion -Command $command
  $payload = [ordered]@{
    timestamp = $event.TimeCreated.ToUniversalTime().ToString("o")
    host = $env:COMPUTERNAME
    source_type = "security_process_creation"
    event_id = $event.Id
    provider = $event.ProviderName
    process_id = $data["NewProcessId"]
    parent_process_id = $data["ProcessId"]
    owner = $owner
    command = $command
    script_block_text = $null
    script_block_id = $null
    script_path = $null
    message_number = $null
    message_total = $null
    command_name = $null
    module_name = $null
    context_info = $null
    host_application = $null
    transcript_path = $null
    transcript_offset = $null
    image = $image
    parent_image = $data["ParentProcessName"]
    channel = $event.LogName
    record_id = $event.RecordId
    suspicious = $suspicion.suspicious
    suspicious_reasons = $suspicion.reasons
  }
  Write-Activity -Activity $payload
}

$sysmonEvents = Read-EventLogBatch -LogName "Microsoft-Windows-Sysmon/Operational" -Ids @(1)

foreach ($event in $sysmonEvents) {
  $data = Get-EventDataMap -Event $event
  $image = $data["Image"]
  if ($image -notmatch '(?i)\\powershell\.exe$|\\pwsh\.exe$') {
    continue
  }

  $command = $data["CommandLine"]
  $suspicion = Get-Suspicion -Command $command
  $payload = [ordered]@{
    timestamp = $event.TimeCreated.ToUniversalTime().ToString("o")
    host = $env:COMPUTERNAME
    source_type = "sysmon_process_creation"
    event_id = $event.Id
    provider = $event.ProviderName
    process_id = $data["ProcessId"]
    parent_process_id = $data["ParentProcessId"]
    owner = $data["User"]
    command = $command
    script_block_text = $null
    script_block_id = $null
    script_path = $null
    message_number = $null
    message_total = $null
    command_name = $null
    module_name = $null
    context_info = $null
    host_application = $null
    transcript_path = $null
    transcript_offset = $null
    image = $image
    parent_image = $data["ParentImage"]
    channel = $event.LogName
    record_id = $event.RecordId
    suspicious = $suspicion.suspicious
    suspicious_reasons = $suspicion.reasons
  }
  Write-Activity -Activity $payload
}

Read-TranscriptBatch
