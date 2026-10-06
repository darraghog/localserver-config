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

# The package default is ListenStream=9090 on every interface, which puts Cockpit's own login on
# the LAN and tailnet beside the Caddy doors. Caddy reaches it at 127.0.0.1:9090 (host network),
# so loopback is all it needs. The empty ListenStream= clears the packaged value first.
log "Binding cockpit.socket to loopback..."
sudo mkdir -p /etc/systemd/system/cockpit.socket.d
sudo tee /etc/systemd/system/cockpit.socket.d/listen.conf > /dev/null << 'EOF'
[Socket]
ListenStream=
ListenStream=127.0.0.1:9090
EOF
sudo systemctl daemon-reload

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
#   COCKPIT_EXTRA_ORIGINS="https://beeblebox.taile98462.ts.net:9443 https://beeblebox.taile98462.ts.net:8090" ./scripts/sudo/setup-cockpit.sh
[[ -n "${COCKPIT_EXTRA_ORIGINS:-}" ]] && ORIGINS="${ORIGINS} ${COCKPIT_EXTRA_ORIGINS}"
sudo mkdir -p /etc/cockpit
sudo tee /etc/cockpit/cockpit.conf > /dev/null << EOF
[WebService]
Origins = ${ORIGINS}
# Served behind the :8090 tailnet path router (compose/tls-proxy/Caddyfile) at /cockpit —
# see docs/NETWORK-CONFIG.md. This is process-wide, so direct :9443 access moves to
# https://<host>:9443/cockpit/ too (verify after changing; Cockpit should redirect
# bare "/" to "/cockpit/" automatically, but confirm on this Cockpit version).
UrlRoot = /cockpit
EOF

log "Restarting cockpit.socket..."
sudo systemctl restart cockpit.socket

log "Done. Cockpit listening on 127.0.0.1:9090 (Caddy fronts it on :9443 and :8090/cockpit)"
log "Login at https://${H}:9443/cockpit/ or https://${H}.local:9443/cockpit/ with your Linux username and password."
log "Also reachable tailnet-only via the path router: https://<tailnet-name>:8090/cockpit/ (see docs/NETWORK-CONFIG.md)."
