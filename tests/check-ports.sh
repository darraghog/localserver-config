#!/usr/bin/env bash
# Assert expected TCP ports are listening (local ss) or reachable (remote /dev/tcp).
# Usage:
#   ./tests/check-ports.sh [--core-only] [remote-host]
#   --core-only  only hello-world and n8n (8080, 5678)
#   (default)    all stacks including tic-tac-toe, Caddy TLS, and Cockpit ports
# Remote: pass hostname or IP as last argument (not --core-only).
set -e

CORE_ONLY=false
HOST=""
for arg in "$@"; do
  if [[ "$arg" == "--core-only" ]]; then
    CORE_ONLY=true
  else
    HOST="$arg"
  fi
done

if [[ "$CORE_ONLY" == true ]]; then
  PORTS=(8080 5678)
  NAMES=("hello-world" "n8n")
else
  PORTS=(8080 5678 8091 8443 8444 8445 9090 9443)
  NAMES=("hello-world" "n8n" "tic-tac-toe" "tls-proxy:8443" "tls-proxy:8444" "tls-proxy:8445" "cockpit" "cockpit-tls")
fi

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
