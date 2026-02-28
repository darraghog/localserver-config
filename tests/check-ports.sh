#!/usr/bin/env bash
# Assert all expected ports are listening. Run on the server (darragh-pc).
# Usage: ./tests/check-ports.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Expected: hello-world :8080, n8n :5678, Caddy :8443 :8444
PORTS=(8080 5678 8443 8444)
NAMES=("hello-world" "n8n" "tls-proxy:8443" "tls-proxy:8444")

failed=0
for i in "${!PORTS[@]}"; do
  port="${PORTS[$i]}"
  name="${NAMES[$i]}"
  if ss -tlnp 2>/dev/null | grep -qE ":${port}\b"; then
    echo "OK ${port} (${name})"
  else
    echo "FAIL ${port} (${name}) - not listening"
    failed=1
  fi
done

if [[ $failed -eq 0 ]]; then
  exit 0
else
  exit 1
fi
