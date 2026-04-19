#!/usr/bin/env bash
# Pre-built n8n image; pull so deploy uses the pinned tag from compose.yaml.
set -euo pipefail
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"
cd "$STACK_DIR"
compose_files=(-f compose.yaml)
if [[ "${N8N_DATABASE:-}" == "postgres" ]] && [[ -f "$STACK_DIR/compose.postgres.yaml" ]]; then
  compose_files+=(-f compose.postgres.yaml)
fi
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)
echo "[build n8n] Pulling image(s)..."
"$COMPOSE_CMD" "${compose_files[@]}" pull "$@"
