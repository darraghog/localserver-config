#!/usr/bin/env bash
# Pre-built nginx image; nothing to compile. Pull ensures image is present before deploy.
set -euo pipefail
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"
cd "$STACK_DIR"
compose_files=(-f compose.yaml)
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)
echo "[build hello-world] Pulling base image..."
"$COMPOSE_CMD" "${compose_files[@]}" pull "$@"
