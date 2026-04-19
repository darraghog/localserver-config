#!/usr/bin/env bash
# Deploy one or more Podman compose stacks independently (no sudo).
# Usage: ./scripts/deploy-stack.sh <stack> [<stack> ...]
# Example: ./scripts/deploy-stack.sh n8n
#          ./scripts/deploy-stack.sh hello-world tls-proxy
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=scripts/lib/stack-helpers.sh
source "$REPO_ROOT/scripts/lib/stack-helpers.sh"

log() { echo "[deploy-stack] $*"; }
installed() { command -v "$1" &>/dev/null; }

install_compose() {
  export PATH="${HOME:-/root}/.local/bin:$PATH"
  if installed podman-compose; then
    return 0
  fi
  if installed uv; then
    log "Installing podman-compose via uv..."
    uv tool install podman-compose -q
    return 0
  fi
  echo "ERROR: podman-compose not found. Run ./scripts/sudo/bootstrap-host.sh or install uv." >&2
  exit 1
}

verify_podman() {
  podman info &>/dev/null || {
    echo "ERROR: Podman not usable (rootless setup?)." >&2
    exit 1
  }
}

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <stack> [<stack> ...]" >&2
  echo "  Deploy only the given stack(s) under compose/<name>/." >&2
  echo "  Full list order: see compose/stack-order (scripts/deploy.sh)." >&2
  exit 1
fi

install_compose
verify_podman

[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

validate_n8n_env_for_stacks "$@"

export N8N_HOST="${N8N_HOST:-$(hostname)}"
export N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL:-https://${N8N_HOST}:8444}"

for s in "$@"; do
  assert_stack_compose_exists "$s" || exit 1
  log "Deploying $s..."
  "$REPO_ROOT/scripts/start-stack.sh" "$s" up
done

log "Done."
