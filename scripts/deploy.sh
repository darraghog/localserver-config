#!/usr/bin/env bash
# Deploy all stacks listed in compose/stack-order (Podman). No sudo.
# For a single stack: ./scripts/deploy-stack.sh <name>
# Requires Podman and podman-compose (see scripts/sudo/bootstrap-host.sh for first-time host setup).
# Usage: ./scripts/deploy.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=scripts/lib/stack-helpers.sh
source "$REPO_ROOT/scripts/lib/stack-helpers.sh"

log() { echo "[deploy] $*"; }
installed() { command -v "$1" &>/dev/null; }

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
  log "ERROR: podman-compose not found. On a new host run: ./scripts/sudo/bootstrap-host.sh"
  log "Or install uv (https://docs.astral.sh/uv/) or podman-compose yourself."
  exit 1
}

verify_podman() {
  log "Verifying Podman..."
  podman info &>/dev/null || { log "Podman failed. Check rootless setup."; exit 1; }
}

main() {
  log "Deploy stacks (repo: $REPO_ROOT)"
  install_compose
  verify_podman

  [[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

  mapfile -t stacks < <(list_stack_order)
  validate_n8n_env_for_stacks "${stacks[@]}"

  export N8N_HOST="${N8N_HOST:-$(hostname)}"
  export N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL:-https://${N8N_HOST}:8444}"

  if [[ "${DEPLOY_SKIP_BUILD:-}" != "1" ]]; then
    log "Building stacks..."
    "$REPO_ROOT/scripts/build-stack.sh" "${stacks[@]}"
  else
    log "Skipping build (DEPLOY_SKIP_BUILD=1)"
  fi

  local s
  for s in "${stacks[@]}"; do
    assert_stack_compose_exists "$s" || exit 1
    log "Deploying $s..."
    "$REPO_ROOT/scripts/start-stack.sh" "$s" up
  done

  # shellcheck source=scripts/lib/post-deploy-caddy.sh
  source "$REPO_ROOT/scripts/lib/post-deploy-caddy.sh"
  reload_tls_proxy_if_possible "${stacks[@]}"
  verify_deployed_stacks_via_caddy "${stacks[@]}"

  H="$(hostname)"
  log "Done."
  echo ""
  echo "  Hello-world:  http://${H}:8080  https://${H}:8443"
  echo "  n8n:          http://${H}:5678  https://${H}:8444"
  echo ""
}

main "$@"
