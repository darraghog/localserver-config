#!/usr/bin/env bash
# Start/stop n8n compose stack (called by localserver-n8n.service)
# Handles env loading and optional postgres overlay.
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$REPO_ROOT/compose/n8n"
COMPOSE_CMD="${HOME}/.local/bin/podman-compose"

# Load secrets
[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

export N8N_HOST="$(hostname)"
export N8N_EDITOR_BASE_URL="https://${N8N_HOST}:8444"

COMPOSE_FILES=(-f "$DIR/compose.yaml")
[[ "${N8N_DATABASE:-}" == "postgres" ]] && COMPOSE_FILES+=(-f "$DIR/compose.postgres.yaml")

ACTION="${1:-up}"
if [[ "$ACTION" == "up" ]]; then
  (cd "$DIR" && "$COMPOSE_CMD" "${COMPOSE_FILES[@]}" up -d)
else
  (cd "$DIR" && "$COMPOSE_CMD" "${COMPOSE_FILES[@]}" down)
fi
