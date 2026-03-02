#!/usr/bin/env bash
# Assert all expected ports are listening.
# Usage: ./tests/check-ports.sh              # local (on darragh-pc)
#        ./tests/check-ports.sh darragh-pc   # remote (from darragh-laptop)

set -e

HOST="${1:-}"

# Expected: hello-world :8080, n8n :5678, Caddy :8443 :8444 :9443
# Note: 9090 requires Cockpit to be installed (scripts/setup-cockpit.sh)
PORTS=(8080 5678 8443 8444 9090 9443)
NAMES=("hello-world" "n8n" "tls-proxy:8443" "tls-proxy:8444" "cockpit" "cockpit-tls")

check_port_local() {
  local port="$1"
  ss -tlnp 2>/dev/null | grep -qE ":${port}\b"
}

check_port_remote() {
  local host="$1" port="$2"
  (echo >/dev/tcp/"$host"/"$port") 2>/dev/null
}

failed=0
for i in "${!PORTS[@]}"; do
  port="${PORTS[$i]}"
  name="${NAMES[$i]}"
  if [[ -n "$HOST" ]]; then
    if check_port_remote "$HOST" "$port"; then
      echo "OK ${port} (${name})"
    else
      echo "FAIL ${port} (${name}) - not reachable on $HOST"
      failed=1
    fi
  else
    if check_port_local "$port"; then
      echo "OK ${port} (${name})"
    else
      echo "FAIL ${port} (${name}) - not listening"
      failed=1
    fi
  fi
done

if [[ $failed -eq 0 ]]; then
  exit 0
else
  exit 1
fi
