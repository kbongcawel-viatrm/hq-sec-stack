# START: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\ossec-main.ps1 -c
# RESTART: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\ossec-main.ps1 -r
# STOP: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\ossec-main.ps1 -x
# ADD AGENT: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\ossec-main.ps1 -a -h HOST-PC
# LIST AGENTS: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\ossec-main.ps1 -l
# SCAN AGENT: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\ossec-main.ps1 -s 003
# RESET BASELINE: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\codex-workspace\ossec-main.ps1 -s 004 --reset



$ErrorActionPreference = "Stop"
$scriptArgs = $args


$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $scriptDir "start-ossec-wsl.ps1"
$stopScript = Join-Path $scriptDir "stop-ossec-wsl.ps1"
$distroName = "CBL-Mariner"

function Show-Help {
    Write-Host "### OSSEC-SERVER ####"
    Write-Host "Usage:"
    Write-Host "  .\ossec-main.ps1 -c             Start the OSSEC server"
    Write-Host "  .\ossec-main.ps1 -r             Restart the OSSEC server"
    Write-Host "  .\ossec-main.ps1 -x             Stop the OSSEC server / WSL"
    Write-Host "  .\ossec-main.ps1 -x -f          Stop WSL service too, requires Administrator"
    Write-Host "  .\ossec-main.ps1 -a -h HOST-PC  Add/enroll a new OSSEC agent"
    Write-Host "  .\ossec-main.ps1 -a -h HOST-PC -ip [IP_ADDRESS]"
    Write-Host "  .\ossec-main.ps1 -a -h HOST-PC -ip any"
    Write-Host "  .\ossec-main.ps1 -l             List registered OSSEC agents"
    Write-Host "  .\ossec-main.ps1 -s [AGENT-ID]  Scan registry and file changes for an agent ID"
    Write-Host "  .\ossec-main.ps1 -s [AGENT-ID] --reset  Reset syscheck baseline for an agent ID"
    Write-Host "  .\ossec-main.ps1 --help         Show this help"
}

function Get-ArgValue {
    param([string]$Name)

    for ($i = 0; $i -lt $scriptArgs.Count; $i++) {
        if ($scriptArgs[$i] -eq $Name -and ($i + 1) -lt $scriptArgs.Count) {
            return $scriptArgs[$i + 1]
        }
    }

    return $null
}

function Add-OssecAgent {
    param(
        [string]$AgentName,
        [string]$AgentIp = "any"
    )

    if (-not $AgentName) {
        throw "Missing host name. Use: .\ossec-main.ps1 -a -h HOST-PC -ip 192.168.1.50"
    }

    if ($AgentName -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "Invalid host name '$AgentName'. Use letters, numbers, dash, underscore, or dot only."
    }

    if ($AgentIp -ne "any" -and $AgentIp -notmatch '^[0-9a-fA-F:.]+$') {
        throw "Invalid agent IP '$AgentIp'. Use an IPv4/IPv6 address, or omit -ip to use any."
    }

    Write-Host "Checking OSSEC server before adding agent..."
    & $startScript -RestartOnly

    Write-Host "Adding OSSEC agent: $AgentName / $AgentIp"
    $addOutput = & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/manage_agents -a '$AgentIp' -n '$AgentName'" 2>&1
    $addOutputText = ($addOutput | Out-String)
    Write-Host $addOutputText

    $agentLine = & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "grep ' $AgentName ' /var/ossec/etc/client.keys | tail -n 1" 2>$null
    $agentId = $null

    if ($agentLine) {
        $agentId = (($agentLine | Select-Object -First 1) -split '\s+')[0]
    }

    Write-Host "Current registered agents:"
    & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/manage_agents -l"

    if ($agentId) {
        Write-Host "Extracted key for $AgentName / agent ID ${agentId}:" -ForegroundColor Green
        $agentKey = & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/manage_agents -e $agentId"
        Write-Host $agentKey
    }
    else {
        Write-Host "Could not auto-detect the new agent ID. Use the list above, then run:" -ForegroundColor Yellow
        Write-Host "wsl -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc `"cd /var/ossec && ./bin/manage_agents -e AGENT_ID`""
    }

    Write-Host ""
    Write-Host "Next step:" -ForegroundColor Yellow
    Write-Host "Run the Windows import-ossecagent-key.ps1 PowerShell script on the target computer."
    Write-Host "Use the extracted key above as that host's AgentKey."
    Write-Host "The agent was registered for source IP '$AgentIp'."
    Write-Host ""
    Write-Host "After the target agent is configured, restart OSSEC with:"
    Write-Host ".\ossec-main.ps1 -r"
}

function List-OssecAgents {
    Write-Host "Checking OSSEC server before listing agents..."
    & $startScript -RestartOnly

    Write-Host "Registered OSSEC agents:" -ForegroundColor Green
    & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/manage_agents -l"
}

function Scan-OssecAgent {
    param(
        [string]$AgentId
    )

    if (-not $AgentId) {
        throw "Missing agent ID. Use: .\ossec-main.ps1 -s 003"
    }

    if ($AgentId -notmatch '^[0-9]+$') {
        throw "Invalid agent ID '$AgentId'. Use only numbers, for example: 003"
    }

    $resetBaseline = $scriptArgs -contains "--reset"

    if ($resetBaseline) {
        Write-Host "Checking OSSEC server before resetting syscheck baseline for agent $AgentId..."
        & $startScript -RestartOnly

        Write-Host "Resetting syscheck baseline for agent ${AgentId}..." -ForegroundColor Yellow
        & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/syscheck_control -u $AgentId"

        Write-Host "Syscheck baseline reset completed for agent ${AgentId}." -ForegroundColor Green
        exit 0
    }

    Write-Host "Checking OSSEC server before scanning agent $AgentId..."
    & $startScript -RestartOnly

    Write-Host "Triggering file integrity scan for agent $AgentId..." -ForegroundColor Green
    & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/agent_control -r -u $AgentId"

    Write-Host ""
    Write-Host "File integrity changes for agent ${AgentId}:" -ForegroundColor Green
    & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/syscheck_control -i $AgentId"

    Write-Host ""
    Write-Host "Registry changes for agent ${AgentId}:" -ForegroundColor Green
    & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/syscheck_control -r -i $AgentId"

    Write-Host ""
    Write-Host "Recent manager alerts:" -ForegroundColor Green
    & wsl.exe -d $distroName -u root --exec docker exec ossec-server /bin/sh -lc "tail -n 80 /var/ossec/logs/alerts/alerts.log 2>/dev/null || true"
}   

if ($args.Count -eq 0 -or $args -contains "--help" -or ($args.Count -eq 1 -and $args -contains "-h")) {
    Show-Help
    exit 0
}

if (-not (Test-Path $startScript)) {
    throw "Start script not found: $startScript"
}

if (-not (Test-Path $stopScript)) {
    throw "Stop script not found: $stopScript"
}

$forceService = $args -contains "-f"

switch ($true) {
    ($args -contains "-c") {
        Write-Host "Starting OSSEC server..."
        & $startScript -Transfer -Pull -ListAgents
        exit $LASTEXITCODE
    }

    ($args -contains "-r") {
        Write-Host "Restarting OSSEC server..."
        & $startScript -RestartOnly -ListAgents
        exit $LASTEXITCODE
    }

    ($args -contains "-x") {
        Write-Host "Stopping OSSEC server / WSL..."

        if ($forceService) {
            & $stopScript -ForceService
        }
        else {
            & $stopScript
        }

        exit $LASTEXITCODE
    }

    ($args -contains "-a") {
        $agentName = Get-ArgValue "-h"
        $agentIp = Get-ArgValue "-ip"

        if (-not $agentIp) {
            $agentIp = "any"
        }

        Add-OssecAgent -AgentName $agentName -AgentIp $agentIp
        exit 0
    }

    ($args -contains "-l") {
        List-OssecAgents
        exit 0
    }

    ($args -contains "-s") {
        $agentId = Get-ArgValue "-s"
        Scan-OssecAgent -AgentId $agentId
        exit 0
    }


    default {
        Write-Host "Unknown command."
        Show-Help
        exit 1
    }
}
