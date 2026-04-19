# Add loopback line(s) to Windows hosts for same-machine HTTPS to WSL/Podman.
# Run in PowerShell as Administrator.
# Required env: LOCALSERVER_HOST_PRIMARY — short hostname (no dots).
# Optional: LOCALSERVER_HOST_SECONDARY — second FQDN or alias (one hosts line is added for it).
# Usage: $env:LOCALSERVER_HOST_PRIMARY='app1'; .\scripts\setup-windows-hosts.ps1

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not $env:LOCALSERVER_HOST_PRIMARY) {
    Write-Error "Set LOCALSERVER_HOST_PRIMARY to your short hostname (host part for https://...:8443)."
    exit 1
}
$primary = $env:LOCALSERVER_HOST_PRIMARY
$lines = @("127.0.0.1 $primary")
if ($env:LOCALSERVER_HOST_SECONDARY) {
    $lines += "127.0.0.1 $($env:LOCALSERVER_HOST_SECONDARY)"
}
$content = Get-Content $hostsPath -Raw

foreach ($line in $lines) {
    $hostname = ($line -split '\s+')[1]
    if ($content -match ('(?m)\s' + [regex]::Escape($hostname) + '(\s|$)')) {
        Write-Host "$hostname already in hosts"
    } else {
        Add-Content -Path $hostsPath -Value "`n$line"
        Write-Host "Added: $line"
    }
}
Write-Host "Try https://${primary}:8443 (after TLS is set up; add LOCALSERVER_HOST_SECONDARY for an extra name)"
