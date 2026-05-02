# RUN: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Import-OssecAgentKey.ps1 -AgentKey "PASTE_KEY_HERE" -ManagerAddress "192.168.1.10"

param(
    [Parameter(Mandatory = $true)]
    [string]$AgentKey,

    [Parameter(Mandatory = $true)]
    [string]$ManagerAddress,

    [int]$ManagerPort = 1514
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-OssecHome {
    $candidates = @(
        "C:\Program Files (x86)\ossec-agent",
        "C:\Program Files\ossec-agent"
    )

    foreach ($path in $candidates) {
        if (Test-Path (Join-Path $path "manage_agents.exe")) {
            return $path
        }
    }

    throw "OSSEC manage_agents.exe was not found."
}

function Set-ClientNodeValue {
    param(
        [xml]$XmlDocument,
        [System.Xml.XmlElement]$ClientNode,
        [string]$NodeName,
        [string]$Value
    )

    $node = $ClientNode.SelectSingleNode($NodeName)
    if (-not $node) {
        $node = $XmlDocument.CreateElement($NodeName)
        [void]$ClientNode.AppendChild($node)
    }

    $node.InnerText = $Value
}

if (-not (Test-IsAdministrator)) {
    throw "Run this script from an elevated PowerShell session."
}

$ossecHome = Get-OssecHome
$manageAgents = Join-Path $ossecHome "manage_agents.exe"
$ossecConf = Join-Path $ossecHome "ossec.conf"

$service = Get-Service | Where-Object {
    $_.Name -match "ossec" -or $_.DisplayName -match "OSSEC"
} | Select-Object -First 1

if (-not $service) {
    throw "OSSEC Windows service was not found."
}

if ($service.Status -eq "Running") {
    Stop-Service -Name $service.Name -Force
    $service.WaitForStatus("Stopped", "00:00:20")
}

Push-Location $ossecHome
try {
    "y`r`n" | & $manageAgents -i $AgentKey
}
finally {
    Pop-Location
}

[xml]$xml = Get-Content $ossecConf
$root = $xml.SelectSingleNode("/ossec_config")
if (-not $root) {
    throw "ossec.conf does not contain an ossec_config root node."
}

$client = $root.SelectSingleNode("client")
if (-not $client) {
    $client = $xml.CreateElement("client")
    [void]$root.AppendChild($client)
}

Set-ClientNodeValue -XmlDocument $xml -ClientNode $client -NodeName "server-ip" -Value $ManagerAddress
Set-ClientNodeValue -XmlDocument $xml -ClientNode $client -NodeName "port" -Value ([string]$ManagerPort)

$xml.Save($ossecConf)

Start-Service -Name $service.Name

Write-Host "OSSEC agent key imported successfully." -ForegroundColor Green
Write-Host "Manager: $ManagerAddress"
Write-Host "Port: $ManagerPort"
