$ErrorActionPreference = "Stop"

$destination = "D:\CBL-Mariner\ossec"

New-Item -ItemType Directory -Force -Path $destination | Out-Null

$tmpTar = Join-Path $env:TEMP "ossec-logs.tar"
if (Test-Path $tmpTar) {
    Remove-Item $tmpTar -Force
}

cmd /c "wsl --cd / -d CBL-Mariner -u root --exec /usr/bin/sh -c ""if [ -d /var/logs/ossec ]; then tar -C /var/logs/ossec -cf - .; fi"" > ""$tmpTar"""

if ((Test-Path $tmpTar) -and ((Get-Item $tmpTar).Length -gt 0)) {
    tar -xf $tmpTar -C $destination
}

if (Test-Path $tmpTar) {
    Remove-Item $tmpTar -Force
}
