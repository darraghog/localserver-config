# Forward Windows ports 8443, 8444 to WSL2.
# Note: Port 53 (DNS/UDP) cannot be forwarded - netsh portproxy is TCP-only.
# Run in PowerShell as Administrator. Re-run after WSL restart (WSL IP may change).
# Usage: .\scripts\setup-windows-port-forward.ps1

# Note: netsh portproxy does NOT support UDP. DNS (port 53) uses UDP, so port 53
# cannot be forwarded. Use local-dns on a Linux host, or hosts file instead.

# Detect WSL2 mirrored networking mode. In mirrored mode, WSL2 shares the Windows
# IP directly — portproxy rules are not needed and will prevent WSL services from
# binding the forwarded ports (iphlpsvc holds them on the Windows side).
$wslconfig = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslconfig) {
    $configContent = Get-Content $wslconfig -Raw
    if ($configContent -match '(?im)^\s*networkingMode\s*=\s*mirrored') {
        Write-Host "ERROR: WSL2 is using mirrored networking mode (.wslconfig: networkingMode=mirrored)."
        Write-Host "Port forwarding is not needed in mirrored mode — WSL2 shares the Windows IP directly."
        Write-Host "Adding portproxy rules will prevent WSL services from binding these ports."
        Write-Host ""
        Write-Host "Instead, ensure Windows Firewall allows inbound TCP on ports 8443 and 8444:"
        Write-Host "  New-NetFirewallRule -DisplayName 'WSL HTTPS' -Direction Inbound -Protocol TCP -LocalPort 8443,8444 -Action Allow"
        exit 1
    }
}

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
Write-Host "Done. Try HTTPS on this PC at https://localhost:8443 (or your hosts name for WSL)."
