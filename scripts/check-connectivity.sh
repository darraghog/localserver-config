#!/usr/bin/env bash
# Diagnose basic connectivity to a server (ping, TCP ports, optional DNS).
# Usage: ./scripts/check-connectivity.sh <server-ip> [ssh-port] [probe-domain]
#   ssh-port defaults to 22
#   probe-domain: optional; dig @$HOST <probe-domain> — pass arg3 or set LOCALSERVER_PROBE_DOMAIN
set -e

HOST="${1:?pass server LAN IP as first argument}"
SSH_PORT="${2:-22}"
PROBE_DOMAIN="${3:-${LOCALSERVER_PROBE_DOMAIN:-}}"

echo "=== Connectivity check -> $HOST ==="

echo -n "Ping $HOST: "
if ping -c 1 -W 2 "$HOST" &>/dev/null; then
  echo "OK"
else
  echo "FAIL (no reply or timeout)"
  echo "  -> Check: same WiFi/LAN? Server powered on? Correct IP?"
fi

for port in "$SSH_PORT" 8443 8444 53; do
  echo -n "TCP $port: "
  if timeout 2 bash -c "echo >/dev/tcp/$HOST/$port" 2>/dev/null; then
    echo "OK"
  else
    echo "FAIL (refused or timeout)"
  fi
done

if [[ -n "$PROBE_DOMAIN" ]]; then
  echo -n "DNS (UDP 53, dig @$HOST $PROBE_DOMAIN): "
  if command -v dig &>/dev/null; then
    if dig +short +time=2 +tries=1 "@$HOST" "$PROBE_DOMAIN" 2>/dev/null | grep -q .; then
      echo "OK"
    else
      echo "FAIL (no response)"
    fi
  else
    echo "SKIP (dig not installed)"
  fi
else
  echo "DNS dig: SKIP (pass probe-domain as arg3 or set LOCALSERVER_PROBE_DOMAIN)"
fi

echo ""
echo "--- If ping FAILs ---"
echo "  - Same network? Firewall allows ICMP?"
echo ""
echo "--- If TCP $SSH_PORT (SSH) FAIL ---"
echo "  - sshd listening? systemctl status ssh (Linux) / Windows OpenSSH Server"
echo "  - Firewall: allow port $SSH_PORT inbound"
echo ""
echo "--- If TCP 8443/8444 FAIL ---"
echo "  - On server: ./tests/check-ports.sh"
echo "  - Windows: firewall / portproxy for WSL — see docs/NETWORK-CONFIG.md"
echo ""
echo "--- If DNS FAIL but TCP 53 OK ---"
echo "  - Windows Firewall: UDP 53 inbound"
echo "  - WSL: mirrored networking may be required for UDP from LAN"
echo ""
