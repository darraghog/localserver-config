#!/usr/bin/env bash
# Add darragh-pc and thelearningcto.com to /etc/hosts for local resolution in WSL.
# Usage: ./scripts/setup-wsl-hosts.sh [SERVER_IP]
#   On darragh-pc (the server): ./scripts/setup-wsl-hosts.sh
#     → adds 127.0.0.1
#   On other WSL machines (laptop): ./scripts/setup-wsl-hosts.sh 192.168.86.237
#     → adds 192.168.86.237
# Run with sudo: sudo ./scripts/setup-wsl-hosts.sh
set -e

IP="${1:-127.0.0.1}"
HOSTS_ENTRY="$IP darragh-pc darragh-pc.thelearningcto.com thelearningcto.com www.thelearningcto.com"

if grep -q "darragh-pc.thelearningcto.com" /etc/hosts 2>/dev/null; then
  echo "Hosts entries already present for thelearningcto.com"
else
  echo "$HOSTS_ENTRY" >> /etc/hosts
  echo "Added: $HOSTS_ENTRY"
fi

echo ""
echo "Verify: getent hosts darragh-pc.thelearningcto.com"
getent hosts darragh-pc.thelearningcto.com 2>/dev/null || true
