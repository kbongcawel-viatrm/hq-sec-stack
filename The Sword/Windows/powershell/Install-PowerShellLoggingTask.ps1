[CmdletBinding()]
param(
  [string]$OutputDirectory = "C:\ProgramData\HQSec\PowerShellLogs",
  [string]$StateDirectory = "C:\ProgramData\HQSec\PowerShellLogs\state",
  [string]$TaskName = "HQSec-PowerShell-Command-Audit",
  [string]$GraylogHost = "127.0.0.1",
  [int]$GraylogGelfUdpPort = 12201,
  [string]$WazuhSyslogHost = "127.0.0.1",
  [int]$WazuhSyslogUdpPort = 1516,
  [int]$IntervalMinutes = 1
)

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $StateDirectory | Out-Null

$scriptPath = Join-Path $OutputDirectory "Collect-PowerShellActivity.ps1"
Copy-Item -Force -Path "$PSScriptRoot\Collect-PowerShellActivity.ps1" -Destination $scriptPath

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Force | Out-Null
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Force | Out-Null
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null

New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockInvocationLogging -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name EnableModuleLogging -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Name "*" -PropertyType String -Value "*" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name EnableTranscripting -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name EnableInvocationHeader -PropertyType DWord -Value 1 -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name OutputDirectory -Value $OutputDirectory -Force

New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name ProcessCreationIncludeCmdLine_Enabled -PropertyType DWord -Value 1 -Force | Out-Null
auditpol.exe /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null

$arguments = @(
  "-NoProfile"
  "-ExecutionPolicy Bypass"
  "-File `"$scriptPath`""
  "-OutputDirectory `"$OutputDirectory`""
  "-StateDirectory `"$StateDirectory`""
  "-GraylogHost `"$GraylogHost`""
  "-GraylogGelfUdpPort $GraylogGelfUdpPort"
  "-WazuhSyslogHost `"$WazuhSyslogHost`""
  "-WazuhSyslogUdpPort $WazuhSyslogUdpPort"
  "-LookbackMinutes $([Math]::Max($IntervalMinutes + 2, 5))"
) -join " "

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 4) -StartWhenAvailable -RunOnlyIfNetworkAvailable
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Installed $TaskName, enabled PowerShell/process logging, GELF forwarding to ${GraylogHost}:${GraylogGelfUdpPort}, and Wazuh fallback syslog to ${WazuhSyslogHost}:${WazuhSyslogUdpPort}."
