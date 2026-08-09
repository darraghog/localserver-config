#!/usr/bin/env bash
# Run as your normal login user — this script calls sudo itself for the
# system-level steps (apt, cockpit.socket, cockpit.conf). Do not sudo the
# whole script: the Podman user-socket step below needs your own (non-root)
# systemd session, not root's.
set -e
log() { echo "[setup-cockpit] $*"; }

H="$(hostname)"

if ! dpkg -l cockpit &>/dev/null 2>&1; then
  log "Installing cockpit and cockpit-podman..."
  sudo apt-get update -qq
  sudo apt-get install -y cockpit cockpit-podman
fi

log "Enabling and starting cockpit.socket..."
sudo systemctl enable --now cockpit.socket

log "Enabling Podman user socket (required for cockpit-podman)..."
if ! systemctl --user show-environment &>/dev/null; then
  log "ERROR: no systemd user session for $(whoami) (XDG_RUNTIME_DIR/D-Bus not available)."
  log "  Fix: sudo loginctl enable-linger $(whoami)  (bootstrap-host.sh should have done this already)"
  log "  then log out/in (or start a new SSH session) and re-run this script."
  exit 1
fi
systemctl --user enable --now podman.socket

log "Configuring cockpit.conf (reverse proxy origins)..."
ORIGINS="https://${H}:9443 https://${H}.local:9443 https://localhost:9443 https://127.0.0.1:9443"
# COCKPIT_EXTRA_ORIGINS: space-separated full origins (scheme://host:port) for names
# not covered above, e.g. a Tailscale MagicDNS FQDN:
#   COCKPIT_EXTRA_ORIGINS="https://beeblebox.taile98462.ts.net:9443" ./scripts/sudo/setup-cockpit.sh
[[ -n "${COCKPIT_EXTRA_ORIGINS:-}" ]] && ORIGINS="${ORIGINS} ${COCKPIT_EXTRA_ORIGINS}"
sudo mkdir -p /etc/cockpit
sudo tee /etc/cockpit/cockpit.conf > /dev/null << EOF
[WebService]
Origins = ${ORIGINS}
EOF

log "Restarting cockpit.socket..."
sudo systemctl restart cockpit.socket

log "Done. Cockpit listening on :9090"
log "Login at https://${H}:9443 or https://${H}.local:9443 with your Linux username and password."
