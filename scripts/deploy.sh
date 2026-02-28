#!/usr/bin/env bash
# Idempotent deploy: Podman + compose stacks (hello-world, n8n, tls-proxy).
# Usage: ./scripts/deploy.sh [--compose-only]
# --compose-only: skip package install (for remote SSH, no sudo)

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

COMPOSE_ONLY=false
for arg in "$@"; do
  [[ "$arg" == "--compose-only" ]] && COMPOSE_ONLY=true && break
done

log() { echo "[deploy] $*"; }
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
    COMPOSE_CMD="podman-compose"
    log "Using podman-compose"
    return 0
  fi
  if podman compose version &>/dev/null; then
    COMPOSE_CMD="podman compose"
    log "Using podman compose"
    return 0
  fi
  if [[ "$COMPOSE_ONLY" == true ]]; then
    log "Compose not found. Run scripts/deploy.sh once interactively."
    exit 1
  fi
  log "Installing podman-compose..."
  sudo apt-get install -y python3-pip 2>/dev/null || true
  pip3 install --user podman-compose
  COMPOSE_CMD="podman-compose"
}

verify_podman() {
  log "Verifying Podman..."
  podman info &>/dev/null || { log "Podman failed. Check rootless setup."; exit 1; }
}

deploy_stacks() {
  export PATH="${HOME:-/root}/.local/bin:$PATH"
  if [[ "$COMPOSE_CMD" == "podman compose" ]]; then
    pgrep -f "podman system service" &>/dev/null || {
      log "Starting Podman system service..."
      podman system service --time=0 &
      sleep 2
    }
  fi

  export N8N_HOST="$(hostname)"
  export N8N_EDITOR_BASE_URL="https://${N8N_HOST}:8444"

  for name in hello-world n8n tls-proxy; do
    [[ "$name" == "tls-proxy" && ! -f "$REPO_ROOT/certs/server.pem" ]] && {
      log "Skip tls-proxy: no certs (run scripts/setup-certs.sh first)"
      continue
    }
    dir="$REPO_ROOT/compose/$name"
    compose="$dir/compose.yaml"
    [[ ! -f "$compose" ]] && compose="$dir/docker-compose.yaml"
    [[ ! -f "$compose" ]] && { log "Skip $name: no compose"; continue; }
    log "Deploying $name..."
    (cd "$dir" && $COMPOSE_CMD -f "$compose" up -d)
  done

  H="$(hostname)"
  log "Done."
  echo ""
  echo "  Hello-world:  http://${H}:8080  https://${H}:8443"
  echo "  n8n:          http://${H}:5678  https://${H}:8444"
  echo ""
}

main() {
  log "Deploy (repo: $REPO_ROOT)"
  if [[ "$COMPOSE_ONLY" == true ]]; then
    log "Compose-only mode"
    install_compose
  else
    install_base
    install_podman
    install_compose
  fi
  verify_podman
  deploy_stacks
}

main "$@"
