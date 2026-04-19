#!/usr/bin/env bash
# Start/stop/restart a single compose stack by directory name (used by systemd and deploy scripts).
# Usage: ./scripts/start-stack.sh <stack-name> up|down|restart
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

if [[ "$SERVICE" == "tls-proxy" && ! -f "$REPO_ROOT/certs/server.pem" ]]; then
  if [[ "$ACTION" == "up" || "$ACTION" == "restart" ]]; then
    echo "[start-stack] Skip tls-proxy: no certs/server.pem (run scripts/setup-certs.sh)" >&2
    exit 0
  fi
fi

compose_files=(-f "$compose")
[[ -f "$DIR/compose.local.yaml" ]] && compose_files+=(-f "$DIR/compose.local.yaml")

run_up() {
  for cid in $(podman ps -a -q --filter "name=${SERVICE}-" 2>/dev/null); do
    echo "[start-stack] Removing legacy container $(podman inspect -f '{{.Name}}' "$cid" 2>/dev/null)"
    podman rm -f "$cid" 2>/dev/null || true
  done
  (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" up -d)
}

run_restart() {
  if ! (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" restart); then
    echo "[start-stack] restart failed for $SERVICE; running up -d..." >&2
    (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" up -d)
  fi
}

if [[ "$ACTION" == "up" ]]; then
  run_up
  if [[ "$SERVICE" == "tls-proxy" ]]; then
    echo "[start-stack] Reloading Caddy in-process (caddy reload)..."
    "$REPO_ROOT/scripts/reload-tls-proxy-caddy.sh" || {
      echo "[start-stack] WARN: caddy reload failed; try: ./scripts/start-stack.sh tls-proxy restart" >&2
    }
  fi
elif [[ "$ACTION" == "down" ]]; then
  (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" down)
elif [[ "$ACTION" == "restart" ]]; then
  run_restart
else
  echo "ERROR: Action must be up, down, or restart (got: $ACTION)" >&2
  exit 1
fi
