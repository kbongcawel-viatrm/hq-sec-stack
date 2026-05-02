param(
    [ValidateSet("Enabled", "AuditOnly", "NotConfigured")]
    [string]$EnforcementMode = "Enabled",

    [string]$ResponseDirectory = "C:\ProgramData\HQSec\Response",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

function Write-HQSecStatus {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $stamp = (Get-Date).ToUniversalTime().ToString("o")
    "$stamp [$Level] $Message" | Add-Content -Path (Join-Path $ResponseDirectory "applocker-containment.log") -Encoding UTF8
}

function New-HQSecFilePathRule {
    param(
        [string]$Name,
        [string]$Sid,
        [string]$Path
    )

    $id = [guid]::NewGuid().ToString()
    @"
    <FilePathRule Id="$id" Name="$Name" Description="HQSec containment allow rule" UserOrGroupSid="$Sid" Action="Allow">
      <Conditions>
        <FilePathCondition Path="$Path" />
      </Conditions>
    </FilePathRule>
"@
}

function New-HQSecRuleCollection {
    param(
        [string]$Type,
        [string]$Mode,
        [object[]]$Rules
    )

    $ruleXml = ($Rules | ForEach-Object {
        New-HQSecFilePathRule -Name $_.Name -Sid $_.Sid -Path $_.Path
    }) -join [Environment]::NewLine

    @"
  <RuleCollection Type="$Type" EnforcementMode="$Mode">
$ruleXml
  </RuleCollection>
"@
}

function New-HQSecContainmentPolicyXml {
    param([string]$Mode)

    $everyone = "S-1-1-0"
    $administrators = "S-1-5-32-544"

    $standardRules = @(
        @{ Name = "HQSec Allow Windows"; Sid = $everyone; Path = "%WINDIR%\*" },
        @{ Name = "HQSec Allow Program Files"; Sid = $everyone; Path = "%PROGRAMFILES%\*" },
        @{ Name = "HQSec Allow Program Files x86"; Sid = $everyone; Path = "%OSDRIVE%\Program Files (x86)\*" },
        @{ Name = "HQSec Allow Administrators"; Sid = $administrators; Path = "*" }
    )

    $installerRules = @(
        @{ Name = "HQSec Allow Windows Installer Cache"; Sid = $everyone; Path = "%WINDIR%\Installer\*" },
        @{ Name = "HQSec Allow Administrators"; Sid = $administrators; Path = "*" }
    )

    $collections = @(
        New-HQSecRuleCollection -Type "Exe" -Mode $Mode -Rules $standardRules
        New-HQSecRuleCollection -Type "Script" -Mode $Mode -Rules $standardRules
        New-HQSecRuleCollection -Type "Msi" -Mode $Mode -Rules $installerRules
        New-HQSecRuleCollection -Type "Dll" -Mode $Mode -Rules $standardRules
    ) -join [Environment]::NewLine

    @"
<AppLockerPolicy Version="1">
$collections
</AppLockerPolicy>
"@
}

New-Item -Path $ResponseDirectory -ItemType Directory -Force | Out-Null

try {
    $exportPath = Join-Path $ResponseDirectory "applocker-containment.xml"
    New-HQSecContainmentPolicyXml -Mode $EnforcementMode | Set-Content -Path $exportPath -Encoding UTF8
    Test-AppLockerPolicy -XmlPolicy $exportPath -Path "$env:windir\System32\cmd.exe", "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -User Everyone | Out-Null

    if ($ValidateOnly) {
        Write-HQSecStatus "Validated AppLocker containment policy XML at $exportPath."
        Write-Output "HQSec AppLocker containment validation completed. Export: $exportPath"
        return
    }

    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "AppLocker containment must run from an elevated administrative session."
    }

    Write-HQSecStatus "Starting AppLocker containment with enforcement mode '$EnforcementMode'."

    Set-Service -Name AppIDSvc -StartupType Automatic
    Start-Service -Name AppIDSvc
    Write-HQSecStatus "Application Identity service is running."

    Set-AppLockerPolicy -XmlPolicy $exportPath -Merge

    Write-HQSecStatus "AppLocker containment policy merged and exported to $exportPath."
    Write-Output "HQSec AppLocker containment completed. Export: $exportPath"
}
catch {
    $failurePath = Join-Path $ResponseDirectory "applocker-containment-failed.txt"
    $message = $_.Exception.Message
    Write-HQSecStatus $message "ERROR"
    $message | Set-Content -Path $failurePath -Encoding UTF8
    throw
}
