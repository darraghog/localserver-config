#!/usr/bin/env bash
set -e
log() { echo "[setup-cockpit] $*"; }

H="$(hostname)"

if ! dpkg -l cockpit &>/dev/null 2>&1; then
  log "Installing cockpit and cockpit-podman..."
  sudo apt-get update -qq
  sudo apt-get install -y cockpit cockpit-podman
  log "Enabling and starting cockpit.socket..."
  sudo systemctl enable --now cockpit.socket
  log "Enabling Podman user socket (required for cockpit-podman)..."
  systemctl --user enable --now podman.socket
fi

log "Configuring cockpit.conf (reverse proxy origins)..."
sudo mkdir -p /etc/cockpit
sudo tee /etc/cockpit/cockpit.conf > /dev/null << EOF
[WebService]
Origins = https://${H}:9443 https://${H}.local:9443 https://localhost:9443 https://127.0.0.1:9443
EOF

log "Restarting cockpit.socket..."
sudo systemctl restart cockpit.socket

log "Done. Cockpit listening on :9090"
log "Login at https://${H}:9443 or https://${H}.local:9443 with your Linux username and password."
