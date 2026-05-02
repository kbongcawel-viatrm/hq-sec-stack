# RUN: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\start-ossec-wsl.ps1 -Transfer -Pull -ListAgents
# RESTART: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\start-ossec-wsl.ps1 -RestartOnly -ListAgents

param(
    [string]$DistroName = "CBL-Mariner",
    [string]$VhdxRoot = "D:\CBL-Mariner",
    [switch]$Transfer,
    [switch]$Pull,
    [switch]$RestartOnly,
    [switch]$ListAgents
)

$ErrorActionPreference = "Stop"

function Get-WslDistros {
    $output = & wsl.exe -l -q 2>$null

    if (-not $output) {
        return @()
    }

    return @(
        $output |
        ForEach-Object { ($_ -replace "`0", "").Trim() } |
        Where-Object { $_ }
    )
}

function Ensure-WslDistro {
    param(
        [string]$DistroName,
        [string]$VhdxRoot
    )

    $distros = Get-WslDistros

    if ($distros -contains $DistroName) {
        Write-Host "WSL distro found: $DistroName"
        return
    }

    Write-Host "WSL distro '$DistroName' was not found. Checking for .vhdx under $VhdxRoot..."

    $vhdx = Get-ChildItem -Path $VhdxRoot -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue |
    Sort-Object FullName |
    Select-Object -First 1

    if (-not $vhdx) {
        throw "No .vhdx file found under $VhdxRoot. Cannot import WSL distro '$DistroName'."
    }

    Write-Host "Importing WSL distro '$DistroName' from $($vhdx.FullName)..."
    & wsl.exe --import-in-place $DistroName $vhdx.FullName

    Write-Host "WSL distro imported successfully."
}

function Start-DockerInWsl {
    param(
        [string]$DistroName
    )

    Write-Host "Checking Docker daemon in WSL..."

    $dockerCommand = "docker info >/dev/null 2>&1 || systemctl start docker 2>/dev/null || service docker start 2>/dev/null || (nohup dockerd >/var/log/dockerd.log 2>&1 & sleep 8); docker info"

    & wsl.exe -d $DistroName -u root --exec /usr/bin/sh -lc $dockerCommand

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker daemon did not start. Last dockerd logs:"
        & wsl.exe -d $DistroName -u root --exec /usr/bin/sh -lc "tail -n 80 /var/log/dockerd.log 2>/dev/null || true"
        throw "Docker daemon is not running in WSL and could not be started."
    }

    Write-Host "Docker daemon is running."
}



Ensure-WslDistro -DistroName $DistroName -VhdxRoot $VhdxRoot
Start-DockerInWsl -DistroName $DistroName

$workspace = "D:\codex-workspace"
$backupDir = Join-Path $workspace "ossec-agent-backup"
$backupFile = Join-Path $backupDir "client.keys"

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Write-Host "Backing up OSSEC agent keys if present..."
$clientKeys = & wsl.exe -d $DistroName -u root --exec /usr/bin/sh -c "if [ -f /opt/ossec-server/data/etc/client.keys ]; then cat /opt/ossec-server/data/etc/client.keys; fi"

if ($clientKeys) {
    $clientKeys | Set-Content -Path $backupFile -Encoding ASCII
    Write-Host "Saved agent key backup to $backupFile"
}
else {
    Write-Host "No existing client.keys found to back up."
}

if ($Transfer) {
    Write-Host "Transferring project to WSL while preserving data..."
    cmd /c "$workspace\transfer-ossec-to-wsl.cmd"
}

if ($Pull) {
    Write-Host "Pulling latest container images..."
    & wsl.exe --cd /opt/ossec-server -d $DistroName -u root --exec /usr/bin/sh -c "mkdir -p data && docker compose pull"
}

if ($RestartOnly) {
    Write-Host "Restarting OSSEC stack..."
    & wsl.exe --cd /opt/ossec-server -d $DistroName -u root --exec /usr/bin/sh -c "docker compose restart postfix-relay ossec-server"
}
else {
    Write-Host "Starting OSSEC stack..."
    & wsl.exe --cd /opt/ossec-server -d $DistroName -u root --exec /usr/bin/sh -c "mkdir -p data && docker compose up -d"
}

Write-Host "Container status:"
& wsl.exe --cd /opt/ossec-server -d $DistroName -u root --exec /usr/bin/sh -c "docker compose ps"

if ($ListAgents) {
    Write-Host "Registered OSSEC agents:" -ForegroundColor Green
    & wsl.exe -d $DistroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/manage_agents -l"
}

Write-Host "Successfully started OSSEC server! in WSL distro - $DistroName" -ForegroundColor Green
exit 0
