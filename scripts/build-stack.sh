#!/usr/bin/env bash
# Build one or more compose stacks: run compose/<stack>/build.sh when present, else
# podman-compose build if a Dockerfile exists, else skip.
# Extra args after "--" are passed to each build.sh and to "podman-compose build".
# Usage:
#   ./scripts/build-stack.sh hello-world n8n tic-tac-toe
#   ./scripts/build-stack.sh tic-tac-toe -- --no-cache
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=scripts/lib/stack-helpers.sh
source "$REPO_ROOT/scripts/lib/stack-helpers.sh"

log() { echo "[build-stack] $*"; }
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

usage() {
  echo "Usage: $(basename "$0") <stack> [<stack> ...] [-- <podman-compose build args...>]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage

stacks=()
extra=()
for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then
    collecting_extra=1
    continue
  fi
  if [[ "${collecting_extra:-}" == 1 ]]; then
    extra+=("$arg")
  else
    stacks+=("$arg")
  fi
done

[[ ${#stacks[@]} -ge 1 ]] || usage

install_compose
verify_podman

for s in "${stacks[@]}"; do
  assert_stack_compose_exists "$s" || exit 1
done

for s in "${stacks[@]}"; do
  dir="$REPO_ROOT/compose/$s"
  custom="$dir/build.sh"
  if [[ -x "$custom" ]]; then
    log "Building $s (compose/$s/build.sh)..."
    "$custom" "${extra[@]}"
  elif [[ -f "$dir/Dockerfile" ]]; then
    log "Building $s (Dockerfile, no build.sh)..."
    compose="$dir/compose.yaml"
    [[ -f "$compose" ]] || compose="$dir/docker-compose.yaml"
    compose_files=(-f "$compose")
    [[ -f "$dir/compose.local.yaml" ]] && compose_files+=(-f "$dir/compose.local.yaml")
    (cd "$dir" && podman-compose "${compose_files[@]}" build "${extra[@]}")
  else
    log "Skipping $s (no compose/$s/build.sh and no Dockerfile)"
  fi
done

log "Done."
