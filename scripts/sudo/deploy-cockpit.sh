#!/usr/bin/env bash
# Install or refresh Cockpit + cockpit-podman (system packages + cockpit.conf).
# Separate from Podman stack deploy — run when you need Cockpit only.
# Usage: ./scripts/sudo/deploy-cockpit.sh <target>
#   target: 'local' for this machine, or an SSH host (same name you use with ssh(1))
# Requires sudo on the target (interactive TTY recommended for password prompts).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="${1:-}"
REMOTE_PATH="~/localserver-config"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $(basename "$0") <target>"
  echo "  target: 'local' or an SSH hostname"
  echo "Examples:"
  echo "  $(basename "$0") local"
  echo "  $(basename "$0") <ssh-host>"
  exit 1
fi

if [[ "$TARGET" == "local" ]]; then
  echo "[deploy-cockpit] target: local ($REPO_ROOT)"
  cd "$REPO_ROOT"
  sudo "$SCRIPT_DIR/setup-cockpit.sh"
  echo ""
  H="$(hostname)"
  echo "[deploy-cockpit] Done. https://${H}:9443"
else
  echo "[deploy-cockpit] target: $TARGET ($REMOTE_PATH)"
  ssh -t "$TARGET" "cd $REMOTE_PATH && chmod +x scripts/sudo/*.sh && sudo ./scripts/sudo/setup-cockpit.sh"
  echo ""
  echo "[deploy-cockpit] Done. https://${TARGET}:9443"
fi
