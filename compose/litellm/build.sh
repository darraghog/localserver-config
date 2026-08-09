#!/usr/bin/env bash
# Pre-built litellm image; pull so deploy uses the pinned tag from compose.yaml.
set -euo pipefail
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"
cd "$STACK_DIR"
echo "[build litellm] Pulling image(s)..."
"$COMPOSE_CMD" -f compose.yaml pull "$@"
