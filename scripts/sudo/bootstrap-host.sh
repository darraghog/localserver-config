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

check_sudo() {
  if sudo -n true 2>/dev/null; then
    return 0
  fi
  log "Requesting sudo access (needed for apt and loginctl)..."
  if ! sudo -v; then
    log "ERROR: sudo failed. If running via 'ssh host command', re-run with 'ssh -t' so sudo has a TTY to prompt on."
    exit 1
  fi
}

install_base() {
  if [[ ! -x /usr/bin/apt-get ]]; then
    log "ERROR: apt-get not found. This script only supports Debian/Ubuntu (apt) hosts;"
    log "  install curl, git, ca-certificates, and Podman manually, then re-run for the systemd/compose steps."
    exit 1
  fi
  log "Ensuring base packages..."
  sudo apt-get update -qq
  # python3-venv: compose/tic-tac-toe/build.sh runs `python3 -m venv` on the host
  # to test before building the image; without it, venv creation fails on ensurepip.
  for pkg in curl git ca-certificates python3-venv; do
    dpkg -l "$pkg" &>/dev/null || sudo apt-get install -y "$pkg"
  done
}

install_podman() {
  installed podman && { log "Podman: $(podman --version)"; return 0; }
  log "Installing Podman..."
  sudo apt-get install -y podman
}

install_compose() {
  export PATH="${HOME:-/root}/.local/bin:$PATH"

  if installed podman-compose; then
    log "Using podman-compose ($(podman-compose --version 2>/dev/null | head -1))"
    return 0
  fi
  if ! installed uv; then
    log "uv not found; installing to ${HOME:-/root}/.local/bin..."
    installed curl || { log "ERROR: curl not found (install_base should have installed it)."; exit 1; }
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="${HOME:-/root}/.local/bin:$PATH"
    installed uv || { log "ERROR: uv install did not put 'uv' on PATH (${HOME:-/root}/.local/bin)."; exit 1; }
  fi
  log "Installing podman-compose via uv..."
  uv tool install podman-compose -q
  installed podman-compose || { log "ERROR: podman-compose still not on PATH after uv install."; exit 1; }
  log "Installed podman-compose ($(podman-compose --version 2>/dev/null | head -1))"
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
  check_sudo
  install_base
  install_podman
  install_compose
  setup_systemd
  verify_podman
  log "Done. Next: configure .env, run ./scripts/setup-certs.sh if needed, then ./scripts/deploy.sh"
}

main "$@"
