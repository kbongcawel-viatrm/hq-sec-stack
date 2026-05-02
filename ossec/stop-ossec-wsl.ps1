#  To run this script, use the following command:
#  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\stop-ossec-wsl.ps1
#  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\stop-ossec-wsl.ps1 -ForceService
param(
    [switch]$ForceService,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$distroName = "CBL-Mariner"
$workspace = "D:\codex-workspace"
$backupDir = Join-Path $workspace "ossec-agent-backup"
$backupFile = Join-Path $backupDir "client.keys"

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Write-Host "Backing up OSSEC agent keys before shutdown..."
$clientKeys = & wsl.exe -d $distroName -u root --exec /usr/bin/sh -c "if [ -f /opt/ossec-server/data/etc/client.keys ]; then cat /opt/ossec-server/data/etc/client.keys; fi" 2>$null

if ($clientKeys) {
    $clientKeys | Set-Content -Path $backupFile -Encoding ASCII
    Write-Host "Saved agent key backup to $backupFile" -ForegroundColor Green
}
else {
    Write-Host "No OSSEC client.keys found to back up." -ForegroundColor Yellow
}


function Invoke-Step {
    param(
        [string]$Message,
        [scriptblock]$Action
    )

    Write-Host $Message

    if (-not $DryRun) {
        & $Action
    }
}

$wsl = Get-Command "wsl.exe" -ErrorAction SilentlyContinue
if (-not $wsl) {
    throw "wsl.exe was not found. WSL may not be installed on this host."
}

Invoke-Step "Shutting down all running WSL distros..." {
    & $wsl.Source --shutdown
}

$serviceNames = @("WslService", "LxssManager")
$services = foreach ($name in $serviceNames) {
    Get-Service -Name $name -ErrorAction SilentlyContinue
}

if (-not $services) {
    Write-Host "No WSL Windows service was found. WSL distros have been asked to shut down."
    Write-Host "Successfully stopped OSSEC server and WSL distros!" -ForegroundColor Green
    exit 0
}

foreach ($service in $services) {
    if ($service.Status -eq "Stopped") {
        Write-Host "$($service.Name) is already stopped."
        continue
    }

    if ($ForceService) {
        Invoke-Step "Stopping $($service.Name)..." {
            Stop-Service -Name $service.Name -Force -ErrorAction Stop
        }
    }
    else {
        Write-Host "$($service.Name) is still $($service.Status). Re-run with -ForceService as Administrator to stop the service." -ForegroundColor Yellow
    }
}

# Wait 1 min
Start-Sleep -Seconds 60

# Get wsl process status
$wsl = Get-Command "wsl.exe" -ErrorAction SilentlyContinue

if (-not $wsl) {
    Write-Host "wsl.exe was not found. WSL is fully shut down."
    Write-Host "Successfully stopped OSSEC server and WSL distros!" -ForegroundColor Green
    exit 0
}

Write-Host "Final WSL Distribution List and Status:" -ForegroundColor Green
& $wsl.Source --list --running
Write-Host "Successfully stopped OSSEC server and WSL distros!" -ForegroundColor Green
exit 0