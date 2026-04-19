#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Ensures Windows Firewall and IPv4→IPv6 portproxy rules for Podman-on-WSL when listeners
  bind only on [::1]. Ports are discovered from the repo Caddyfile plus optional extras.

.DESCRIPTION
  - Parses compose/tls-proxy/Caddyfile for site listener ports (e.g. ":8443 {", "host:8443 {").
  - Merges ports from compose/windows-lan-extra-ports.txt (host-published services not in Caddy).
  - Optional -ExtraPorts for one-off additions.
  - If -Ports is set, discovery is skipped and only those ports are used (legacy override).

  For each TCP port: inbound firewall allow + netsh v4tov6 (0.0.0.0 -> [::1]).
  A state file (%LOCALAPPDATA%\localserver-config\windows-lan-ports.state.txt) removes stale
  portproxy entries when you delete a site from the Caddyfile.

  Run as Administrator; schedule at startup via Task Scheduler (see end of this comment).

  Usage:
    .\scripts\setup-windows-podman-lan-ports.ps1
    .\scripts\setup-windows-podman-lan-ports.ps1 -Caddyfile "D:\repo\compose\tls-proxy\Caddyfile"
    .\scripts\setup-windows-podman-lan-ports.ps1 -ExtraPorts 9090
    .\scripts\setup-windows-podman-lan-ports.ps1 -Ports 8080,8443   # manual only, no discovery

  Task Scheduler: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<repo>\scripts\setup-windows-podman-lan-ports.ps1"

  See docs/NETWORK-CONFIG.md (WSL2 Podman / IPv6 localhost).
#>
param(
    [string]$Caddyfile = "",
    [string]$ExtraPortsFile = "",
    [int[]]$ExtraPorts = @(),
    [int[]]$Ports = @(),
    [string]$StateDir = ""
)

$ErrorActionPreference = 'Stop'
$fwGroup = 'localserver-config-podman-lan'

function Get-TrimmedLineWithoutComment {
    param([string]$Line)
    $t = $Line.Trim()
    if ($t -eq '') { return '' }
    $hash = $t.IndexOf('#')
    if ($hash -ge 0) { $t = $t.Substring(0, $hash).Trim() }
    return $t
}

function Get-PortFromCaddyAddressToken {
    param([string]$Token)
    $a = $Token.Trim()
    if ($a -eq '') { return $null }
    # [::]:8443
    if ($a -match '^\[.+?\]:(\d+)$') { return [int]$Matches[1] }
    # :8443
    if ($a -match '^:(\d+)$') { return [int]$Matches[1] }
    # https://host:port or http://...
    if ($a -match '^https://') {
        if ($a -match ':(\d+)(?:/|\?|$)') { return [int]$Matches[1] }
        return 443
    }
    if ($a -match '^http://') {
        if ($a -match ':(\d+)(?:/|\?|$)') { return [int]$Matches[1] }
        return 80
    }
    # host:port (avoid treating scheme-less IPv6 here)
    if ($a -notmatch '^\[' -and $a -match ':(\d+)$') { return [int]$Matches[1] }
    return $null
}

function Get-CaddyfileListenPorts {
    param([string]$Path)
    $set = [System.Collections.Generic.HashSet[int]]::new()
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Caddyfile not found: $Path"
        return @()
    }
    $skipLinePrefixes = @(
        'bind ', 'tls ', 'reverse_proxy ', 'encode ', 'log ', 'respond ', 'file_server ',
        'abort ', 'redir ', 'import ', 'handle ', 'handle_path ', 'route ', 'try_files ',
        'root ', 'header ', 'basicauth ', 'php_fastcgi ', 'auto_https '
    )
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $t = Get-TrimmedLineWithoutComment $line
        if ($t -eq '' -or $t -eq '}') { continue }
        if ($t -match '^\{') { continue }
        if ($t -match '^@') { continue }
        $skip = $false
        foreach ($p in $skipLinePrefixes) {
            if ($t.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) { $skip = $true; break }
        }
        if ($skip) { continue }
        if ($t -notmatch '\{') { continue }
        $open = $t.IndexOf('{')
        $sitePart = $t.Substring(0, $open).Trim()
        if ([string]::IsNullOrWhiteSpace($sitePart)) { continue }
        foreach ($chunk in ($sitePart -split ',')) {
            $port = Get-PortFromCaddyAddressToken $chunk
            if ($null -ne $port -and $port -ge 1 -and $port -le 65535) {
                [void]$set.Add($port)
            }
        }
    }
    return @($set | Sort-Object)
}

function Get-PortsFromExtraFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $list = [System.Collections.Generic.List[int]]::new()
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $t = Get-TrimmedLineWithoutComment $line
        if ($t -eq '') { continue }
        if ($t -match '^(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -ge 1 -and $n -le 65535) { $list.Add($n) }
        }
    }
    return @($list | Sort-Object -Unique)
}

if (-not $Caddyfile) {
    $Caddyfile = Join-Path $PSScriptRoot '..\compose\tls-proxy\Caddyfile'
}
if (-not $ExtraPortsFile) {
    $ExtraPortsFile = Join-Path $PSScriptRoot '..\compose\windows-lan-extra-ports.txt'
}
if (-not $StateDir) {
    $StateDir = Join-Path $env:LOCALAPPDATA 'localserver-config'
}

$caddyResolved = try { (Resolve-Path -LiteralPath $Caddyfile).Path } catch { $Caddyfile }
$extraResolved = try { (Resolve-Path -LiteralPath $ExtraPortsFile).Path } catch { $ExtraPortsFile }

[int[]]$desired = @()
if ($Ports.Count -gt 0) {
    $desired = @($Ports | Sort-Object -Unique)
    Write-Host "Using explicit -Ports only: $($desired -join ', ')"
} else {
    $fromCaddy = Get-CaddyfileListenPorts $caddyResolved
    $fromFile = Get-PortsFromExtraFile $extraResolved
    $desired = @($fromCaddy + $fromFile + $ExtraPorts | Sort-Object -Unique)
    Write-Host "Caddyfile: $caddyResolved -> ports: $(if ($fromCaddy.Count) { $fromCaddy -join ', ' } else { '(none)' })"
    Write-Host "Extra file: $extraResolved -> ports: $(if ($fromFile.Count) { $fromFile -join ', ' } else { '(none)' })"
    if ($ExtraPorts.Count) {
        Write-Host "Extra -Ports param: $($ExtraPorts -join ', ')"
    }
}

if ($desired.Count -eq 0) {
    Write-Error "No ports to configure. Add sites to Caddyfile, lines to windows-lan-extra-ports.txt, or pass -Ports."
    exit 1
}

Write-Host "Applying firewall + portproxy for: $($desired -join ', ')"

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
# Plain text (one port per line) so a single port round-trips; JSON would collapse one-element arrays.
$statePath = Join-Path $StateDir 'windows-lan-ports.state.txt'
[int[]]$previous = @()
if (Test-Path -LiteralPath $statePath) {
    try {
        $previous = @(Get-Content -LiteralPath $statePath | ForEach-Object {
            $s = $_.Trim()
            if ($s -match '^\d+$') { [int]$s }
        } | Where-Object { $_ -ge 1 -and $_ -le 65535 })
    } catch {
        Write-Warning "Could not read state file (stale portproxy cleanup skipped): $_"
    }
}

foreach ($port in $previous) {
    if ($port -notin $desired) {
        netsh interface portproxy delete v4tov6 listenport=$port listenaddress=0.0.0.0 2>$null | Out-Null
        Write-Host "Removed stale portproxy for TCP $port"
    }
}

Get-NetFirewallRule -Group $fwGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

foreach ($port in $desired) {
    $ruleDisplayName = "localserver-config LAN TCP $port"
    New-NetFirewallRule -DisplayName $ruleDisplayName -Group $fwGroup -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow | Out-Null
    Write-Host "Firewall: allow TCP $port ($ruleDisplayName)"
}

foreach ($port in $desired) {
    netsh interface portproxy delete v4tov6 listenport=$port listenaddress=0.0.0.0 2>$null | Out-Null
    netsh interface portproxy add v4tov6 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=::1 | Out-Null
    Write-Host "Portproxy: v4tov6 0.0.0.0:$port -> [::1]:$port"
}

@($desired | Sort-Object -Unique) | Set-Content -LiteralPath $statePath -Encoding UTF8
Write-Host "State saved: $statePath"

Write-Host ""
Write-Host "Done."
Write-Host "Verify portproxy: netsh interface portproxy show all"
Write-Host "Verify firewall:   Get-NetFirewallRule -Group '$fwGroup' | Format-Table DisplayName, Enabled, Direction, Action"
