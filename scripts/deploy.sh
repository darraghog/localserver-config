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
  COMPOSE_VENV="${HOME:-/root}/.local/share/podman-compose-venv"
  COMPOSE_BIN="${COMPOSE_VENV}/bin/podman-compose"

  # Prefer podman-compose (avoids Docker Compose "conmon failed" with podman compose)
  if [[ -x "$COMPOSE_BIN" ]]; then
    COMPOSE_CMD="$COMPOSE_BIN"
    log "Using podman-compose (venv)"
    return 0
  fi
  if installed podman-compose; then
    COMPOSE_CMD="podman-compose"
    log "Using podman-compose"
    return 0
  fi
  # In compose-only mode, try installing venv without sudo (no apt)
  if [[ "$COMPOSE_ONLY" == true ]]; then
    log "Compose not found, installing podman-compose (venv)..."
    mkdir -p "$(dirname "$COMPOSE_VENV")"
    if python3 -m venv "$COMPOSE_VENV" 2>/dev/null && "$COMPOSE_VENV/bin/pip" install -q podman-compose 2>/dev/null; then
      COMPOSE_CMD="$COMPOSE_BIN"
      log "Installed podman-compose"
      return 0
    fi
    log "Compose not found. Run scripts/deploy.sh once interactively (with sudo for apt)."
    exit 1
  fi
  log "Installing podman-compose (venv, no sudo)..."
  mkdir -p "$(dirname "$COMPOSE_VENV")"
  python3 -m venv "$COMPOSE_VENV" && "$COMPOSE_VENV/bin/pip" install -q podman-compose
  COMPOSE_CMD="$COMPOSE_BIN"
  log "Installed podman-compose"
}

verify_podman() {
  log "Verifying Podman..."
  podman info &>/dev/null || { log "Podman failed. Check rootless setup."; exit 1; }
}

deploy_stacks() {
  export PATH="${HOME:-/root}/.local/bin:$PATH"
  # podman-compose uses podman CLI directly; podman compose needs the API service
  if [[ "$COMPOSE_CMD" == "podman compose" ]]; then
    pgrep -f "podman system service" &>/dev/null || {
      log "Starting Podman system service..."
      podman system service --time=0 &
      sleep 2
    }
  fi

  [[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

  [[ -z "${N8N_BASIC_AUTH_PASSWORD:-}" ]] && {
    log "ERROR: N8N_BASIC_AUTH_PASSWORD is not set. Copy .env.example to .env and set a password."
    exit 1
  }
  [[ -z "${N8N_ENCRYPTION_KEY:-}" ]] && {
    log "ERROR: N8N_ENCRYPTION_KEY is not set. Generate one with: openssl rand -hex 32"
    exit 1
  }

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
    # Stop and remove legacy Docker Compose-style containers (hyphenated) that conflict with podman-compose
    for cid in $(podman ps -a -q --filter "name=${name}-" 2>/dev/null); do
      log "Removing legacy container $(podman inspect -f '{{.Name}}' "$cid" 2>/dev/null)"
      podman rm -f "$cid" 2>/dev/null || true
    done
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
