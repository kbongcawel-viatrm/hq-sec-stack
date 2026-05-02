param(
    [int]$IdleMinutes = 30,
    [string]$DistroName = "CBL-Mariner",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($IdleMinutes -lt 1) {
    throw "IdleMinutes must be at least 1."
}

$idleSeconds = $IdleMinutes * 60
$sessionTitle = "$DistroName (nobody)"

$rcTemplate = @'
export TMOUT={0}
readonly TMOUT
export HISTFILE=/dev/null
export PS1='CBL-Mariner nobody:\w\$ '
printf '\nCBL-Mariner session running as %s. Idle timeout: {1} minute(s).\n' "$(id -un 2>/dev/null || printf unknown)"
printf 'Close this terminal or idle at the prompt to stop the CBL-Mariner WSL distro.\n\n'
'@

$rcContent = $rcTemplate -f $idleSeconds, $IdleMinutes
$rcBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($rcContent))
$linuxCommand = "printf '%s' '$rcBase64' | /usr/bin/base64 -d > /tmp/cbl-mariner-idle-guard.bashrc; exec /usr/bin/bash --rcfile /tmp/cbl-mariner-idle-guard.bashrc -i"

$childScript = @"
`$Host.UI.RawUI.WindowTitle = '$sessionTitle'
`$ErrorActionPreference = 'Stop'
& wsl.exe --cd / -d '$DistroName' --exec /usr/bin/bash -lc @'
$linuxCommand
'@
"@

$encodedChild = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childScript))

if ($DryRun) {
    [pscustomobject]@{
        DistroName = $DistroName
        IdleMinutes = $IdleMinutes
        StartsAs = "configured WSL default user"
        Launches = "wsl.exe --cd / -d $DistroName --exec /usr/bin/bash -lc <idle-guard>"
        OnTerminalExit = "wsl.exe --terminate $DistroName"
    } | Format-List
    exit 0
}

$terminal = Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-EncodedCommand", $encodedChild
) -PassThru

$watchdogScript = @"
`$ErrorActionPreference = 'SilentlyContinue'
Wait-Process -Id $($terminal.Id)
& wsl.exe --terminate '$DistroName' | Out-Null
"@

$encodedWatchdog = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($watchdogScript))

Start-Process -FilePath "powershell.exe" -WindowStyle Hidden -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-EncodedCommand", $encodedWatchdog
) | Out-Null

Write-Host "Started $sessionTitle with a $IdleMinutes minute idle timeout."
Write-Host "A hidden watchdog will terminate only the $DistroName WSL distro when the terminal exits."
