# Add darragh-pc -> 127.0.0.1 so https://darragh-pc:8443 uses localhost (which works).
# Run in PowerShell as Administrator.
# Usage: .\scripts\setup-windows-hosts.ps1

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$line = "127.0.0.1 darragh-pc"
$content = Get-Content $hostsPath -Raw
if ($content -match "127\.0\.0\.1\s+darragh-pc") {
    Write-Host "darragh-pc already in hosts"
} else {
    Add-Content -Path $hostsPath -Value "`n$line"
    Write-Host "Added: $line"
}
Write-Host "Try https://darragh-pc:8443"
