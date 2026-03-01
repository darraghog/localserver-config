#!/usr/bin/env bash
# Diagnose connectivity from darragh-laptop (192.168.86.236) to darragh-pc (192.168.86.237).
# Usage: ./scripts/check-connectivity.sh [HOST] [SSH_PORT]
#   HOST defaults to 192.168.86.237 (darragh-pc)
#   SSH_PORT defaults to 2222

set -e

HOST="${1:-192.168.86.237}"
SSH_PORT="${2:-2222}"
echo "=== Connectivity check: darragh-laptop -> $HOST (darragh-pc) ==="

# 1. Ping
echo -n "Ping $HOST: "
if ping -c 1 -W 2 "$HOST" &>/dev/null; then
  echo "OK"
else
  echo "FAIL (no reply or timeout)"
  echo "  -> Check: same WiFi/LAN? darragh-pc powered on? Correct IP?"
fi

# 2. TCP ports
for port in "$SSH_PORT" 8443 8444 53; do
  echo -n "TCP $port: "
  if timeout 2 bash -c "echo >/dev/tcp/$HOST/$port" 2>/dev/null; then
    echo "OK"
  else
    echo "FAIL (refused or timeout)"
  fi
done

# 3. DNS (UDP 53)
echo -n "DNS (UDP 53, dig): "
if command -v dig &>/dev/null; then
  if dig +short +time=2 +tries=1 @$HOST darragh-pc.thelearningcto.com 2>/dev/null | grep -q .; then
    echo "OK"
  else
    echo "FAIL (no response)"
  fi
else
  echo "SKIP (dig not installed)"
fi

# 4. Summary / next steps
echo ""
echo "--- If ping FAILs ---"
echo "  - Same network? Both on 192.168.86.x?"
echo "  - darragh-pc: ip addr (check LAN IP)"
echo "  - Windows Firewall on darragh-pc: allow ICMP (ping)"
echo ""
echo "--- If TCP $SSH_PORT (SSH) FAIL ---"
echo "  - darragh-pc: systemctl status ssh"
echo "  - Windows Firewall: allow port $SSH_PORT inbound"
echo ""
echo "--- If TCP 8443/8444 FAIL ---"
echo "  - darragh-pc: run ./tests/check-ports.sh"
echo "  - Windows Firewall: allow 8443, 8444 inbound"
echo ""
echo "--- If DNS FAIL but TCP 53 OK ---"
echo "  - Windows Firewall: add rule for UDP 53 inbound"
echo "  - WSL: .wslconfig needs networkingMode=mirrored"
echo ""
