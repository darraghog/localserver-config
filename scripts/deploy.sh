#!/usr/bin/env bash
# Idempotent deploy: Podman + compose stacks (hello-world, n8n, tls-proxy).
# Usage: ./scripts/deploy.sh [--compose-only]
# --compose-only: skip package install and systemd setup (for remote SSH, no sudo)

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

  # Prefer podman-compose (avoids Docker Compose "conmon failed" with podman compose)
  if installed podman-compose; then
    COMPOSE_CMD=("podman-compose")
    log "Using podman-compose ($(podman-compose --version 2>/dev/null | head -1))"
    return 0
  fi
  if installed uv; then
    log "Installing podman-compose via uv..."
    uv tool install podman-compose -q
    COMPOSE_CMD=("podman-compose")
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

deploy_stacks() {
  export PATH="${HOME:-/root}/.local/bin:$PATH"

  [[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

  [[ -z "${N8N_BASIC_AUTH_PASSWORD:-}" ]] && {
    log "ERROR: N8N_BASIC_AUTH_PASSWORD is not set. Copy .env.example to .env and set a password."
    exit 1
  }
  [[ -z "${N8N_ENCRYPTION_KEY:-}" ]] && {
    log "ERROR: N8N_ENCRYPTION_KEY is not set. Generate one with: openssl rand -hex 32"
    exit 1
  }

  export N8N_HOST="${N8N_HOST:-$(hostname)}"
  export N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL:-https://${N8N_HOST}:8444}"

  if [[ "${N8N_DATABASE:-}" == "postgres" ]]; then
    podman volume create postgres-data 2>/dev/null && log "Created volume: postgres-data" || log "Volume exists: postgres-data"
  fi

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
    compose_files=(-f "$compose")
    [[ "$name" == "n8n" && "${N8N_DATABASE:-}" == "postgres" ]] && compose_files+=(-f "$dir/compose.postgres.yaml")
    log "Deploying $name${N8N_DATABASE:+ (db: $N8N_DATABASE)}..."
    (cd "$dir" && "${COMPOSE_CMD[@]}" "${compose_files[@]}" up -d)
  done

  H="$(hostname)"
  log "Done."
  echo ""
  echo "  Hello-world:  http://${H}:8080  https://${H}:8443"
  echo "  n8n:          http://${H}:5678  https://${H}:8444"
  echo ""
}

setup_systemd() {
  local unit_src="$REPO_ROOT/systemd/user"
  local unit_dst="${HOME}/.config/systemd/user"
  local units=(localserver-hello-world localserver-n8n localserver-tls-proxy)

  log "Installing systemd user units..."
  mkdir -p "$unit_dst"

  for unit in "${units[@]}"; do
    sed \
      -e "s|__REPO_ROOT__|${REPO_ROOT}|g" \
      -e "s|__HOME__|${HOME}|g" \
      "$unit_src/${unit}.service" > "$unit_dst/${unit}.service"
    log "  Installed ${unit}.service"
  done

  systemctl --user daemon-reload
  systemctl --user enable "${units[@]/%/.service}"
  log "Systemd units enabled"

  if sudo loginctl enable-linger "$(whoami)" 2>/dev/null; then
    log "Lingering enabled (user services start at boot)"
  else
    log "WARNING: Could not enable lingering (run: sudo loginctl enable-linger $(whoami))"
  fi
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
    setup_systemd
  fi
  verify_podman
  deploy_stacks
}

main "$@"
