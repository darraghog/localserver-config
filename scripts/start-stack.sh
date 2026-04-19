#!/usr/bin/env bash
# Start/stop a single compose stack by directory name (used by systemd and deploy scripts).
# Usage: ./scripts/start-stack.sh <stack-name> up|down
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="${1:?stack name}"
ACTION="${2:-up}"
COMPOSE_CMD="${HOME}/.local/bin/podman-compose"

[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

if [[ "$SERVICE" == "n8n" ]]; then
  exec "$REPO_ROOT/scripts/start-n8n.sh" "$ACTION"
fi

DIR="$REPO_ROOT/compose/$SERVICE"
[[ -d "$DIR" ]] || {
  echo "ERROR: Unknown stack '$SERVICE' (no compose/$SERVICE)." >&2
  exit 1
}

compose="$DIR/compose.yaml"
[[ -f "$compose" ]] || compose="$DIR/docker-compose.yaml"
[[ -f "$compose" ]] || {
  echo "ERROR: No compose.yaml in compose/$SERVICE" >&2
  exit 1
}

if [[ "$SERVICE" == "tls-proxy" && "$ACTION" == "up" && ! -f "$REPO_ROOT/certs/server.pem" ]]; then
  echo "[start-stack] Skip tls-proxy: no certs/server.pem (run scripts/setup-certs.sh)" >&2
  exit 0
fi

compose_files=(-f "$compose")
[[ -f "$DIR/compose.local.yaml" ]] && compose_files+=(-f "$DIR/compose.local.yaml")

if [[ "$ACTION" == "up" ]]; then
  for cid in $(podman ps -a -q --filter "name=${SERVICE}-" 2>/dev/null); do
    echo "[start-stack] Removing legacy container $(podman inspect -f '{{.Name}}' "$cid" 2>/dev/null)"
    podman rm -f "$cid" 2>/dev/null || true
  done
  (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" up -d)
elif [[ "$ACTION" == "down" ]]; then
  (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" down)
else
  echo "ERROR: Action must be up or down (got: $ACTION)" >&2
  exit 1
fi
