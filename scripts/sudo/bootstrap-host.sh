#!/usr/bin/env bash
# One-time host setup: apt packages, Podman, podman-compose, systemd user units, loginctl linger.
# Run as your normal login user — the script calls sudo for apt and loginctl (do not sudo the whole script).
# Does not start compose stacks — run scripts/deploy.sh after .env and certs are ready.
# Usage: ./scripts/sudo/bootstrap-host.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

log() { echo "[bootstrap-host] $*"; }
installed() { command -v "$1" &>/dev/null; }

install_base() {
  [[ ! -x /usr/bin/apt-get ]] && return 0
  log "Ensuring base packages..."
  sudo apt-get update -qq
  for pkg in curl git ca-certificates; do
    dpkg -l "$pkg" &>/dev/null || sudo apt-get install -y "$pkg"
  done
}

install_podman() {
  installed podman && { log "Podman: $(podman --version)"; return 0; }
  log "Installing Podman..."
  sudo apt-get update -qq && sudo apt-get install -y podman
}

install_compose() {
  export PATH="${HOME:-/root}/.local/bin:$PATH"

  if installed podman-compose; then
    log "Using podman-compose ($(podman-compose --version 2>/dev/null | head -1))"
    return 0
  fi
  if installed uv; then
    log "Installing podman-compose via uv..."
    uv tool install podman-compose -q
    log "Installed podman-compose"
    return 0
  fi
  log "ERROR: podman-compose not found. Install uv (https://docs.astral.sh/uv/) or podman-compose."
  exit 1
}

verify_podman() {
  log "Verifying Podman..."
  podman info &>/dev/null || { log "Podman failed. Check rootless setup."; exit 1; }
}

setup_systemd() {
  local unit_src="$REPO_ROOT/systemd/user"
  local unit_dst="${HOME}/.config/systemd/user"
  local f unit enabled=()

  log "Installing systemd user units (localserver-*.service)..."
  mkdir -p "$unit_dst"

  shopt -s nullglob
  for f in "$unit_src"/localserver-*.service; do
    unit=$(basename "$f")
    sed \
      -e "s|__REPO_ROOT__|${REPO_ROOT}|g" \
      -e "s|__HOME__|${HOME}|g" \
      "$f" > "$unit_dst/$unit"
    enabled+=("$unit")
    log "  Installed $unit"
  done
  shopt -u nullglob

  [[ ${#enabled[@]} -eq 0 ]] && {
    log "WARNING: No systemd/user/localserver-*.service files found."
    return 0
  }

  systemctl --user daemon-reload
  systemctl --user enable "${enabled[@]}"
  log "Systemd units enabled"

  if sudo loginctl enable-linger "$(whoami)" 2>/dev/null; then
    log "Lingering enabled (user services start at boot)"
  else
    log "WARNING: Could not enable lingering (run: sudo loginctl enable-linger $(whoami))"
  fi
}

main() {
  log "Host bootstrap (repo: $REPO_ROOT)"
  install_base
  install_podman
  install_compose
  setup_systemd
  verify_podman
  log "Done. Next: configure .env, run ./scripts/setup-certs.sh if needed, then ./scripts/deploy.sh"
}

main "$@"
