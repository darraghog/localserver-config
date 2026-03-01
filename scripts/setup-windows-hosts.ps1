# Add darragh-pc and darragh-pc.thelearningcto.com -> 127.0.0.1 for same-machine HTTPS.
# Run in PowerShell as Administrator.
# Usage: .\scripts\setup-windows-hosts.ps1

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$lines = @("127.0.0.1 darragh-pc", "127.0.0.1 darragh-pc.thelearningcto.com")
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
Write-Host "Try https://darragh-pc:8443 or https://darragh-pc.thelearningcto.com:8443"
