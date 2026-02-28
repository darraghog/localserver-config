# Forward Windows ports 8443, 8444 to WSL2 so browser can reach darragh-pc / LAN IP.
# Run in PowerShell as Administrator. Re-run after WSL restart (WSL IP may change).
# Usage: .\scripts\setup-windows-port-forward.ps1

$ports = @(8443, 8444)
$wslIp = (wsl hostname -I 2>$null).Trim().Split()[0]
if (-not $wslIp -or $wslIp -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    Write-Host "Error: Could not get WSL IP. Is WSL running?"
    exit 1
}
Write-Host "WSL IP: $wslIp"
foreach ($port in $ports) {
    netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>$null | Out-Null
    netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIp
    Write-Host "Forwarded $port -> ${wslIp}:$port"
}
netsh advfirewall firewall delete rule name="WSL HTTPS" 2>$null | Out-Null
netsh advfirewall firewall add rule name="WSL HTTPS" dir=in action=allow protocol=TCP localport=8443,8444 | Out-Null
Write-Host "Firewall: allowed 8443, 8444"
Write-Host "Done. Try https://darragh-pc:8443 or https://127.0.0.1:8443"
