#!/usr/bin/env bash
# Append one line to /etc/hosts in WSL (requires sudo).
# Hostnames must come from the environment or from command-line arguments — no defaults.
#
# Option A — full line in env (IP and space-separated names):
#   sudo LOCALSERVER_HOSTS_ENTRY="<ip> <shortname> <fqdn> ..." ./scripts/sudo/setup-wsl-hosts.sh
# Option B — IP and names as arguments (first token = IP, rest = names):
#   sudo ./scripts/sudo/setup-wsl-hosts.sh <ip> <shortname> <fqdn> ...
#
# Idempotency: set LOCALSERVER_HOSTS_MARKER to a unique substring of your line (defaults to the second field).
set -e

if [[ -n "${LOCALSERVER_HOSTS_ENTRY:-}" ]]; then
  HOSTS_ENTRY="$LOCALSERVER_HOSTS_ENTRY"
elif [[ $# -ge 2 ]]; then
  HOSTS_ENTRY="$*"
else
  echo "ERROR: Provide hosts via LOCALSERVER_HOSTS_ENTRY or: $0 <ip> <name> [more-names...]" >&2
  exit 1
fi

MARKER="${LOCALSERVER_HOSTS_MARKER:-$(echo "$HOSTS_ENTRY" | awk '{print $2}')}"
[[ -n "$MARKER" ]] || {
  echo "ERROR: Could not derive marker from HOSTS_ENTRY; set LOCALSERVER_HOSTS_MARKER." >&2
  exit 1
}

if grep -qF "$MARKER" /etc/hosts 2>/dev/null; then
  echo "Hosts entries already present (marker: $MARKER)"
else
  echo "$HOSTS_ENTRY" >> /etc/hosts
  echo "Added: $HOSTS_ENTRY"
fi

verify_name="$(echo "$HOSTS_ENTRY" | awk '{print $2}')"
echo ""
echo "Verify: getent hosts $verify_name"
getent hosts "$verify_name" 2>/dev/null || true
