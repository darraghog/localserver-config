#!/usr/bin/env bash
# Reload Caddy in the tls-proxy stack without restarting the container (keeps existing connections).
# Uses: podman-compose exec caddy caddy reload ...
# Usage: ./scripts/reload-tls-proxy-caddy.sh
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"

if ! command -v podman-compose &>/dev/null; then
  echo "[reload-tls-proxy-caddy] ERROR: podman-compose not found in PATH." >&2
  exit 1
fi

DIR="$REPO_ROOT/compose/tls-proxy"
compose_files=(-f "$DIR/compose.yaml")
[[ -f "$DIR/compose.local.yaml" ]] && compose_files+=(-f "$DIR/compose.local.yaml")

reload_once() {
  # Service name must match compose/tls-proxy/compose.yaml. Prefer -T (no TTY); fall back for older podman-compose.
  (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" exec -T caddy \
    caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile) ||
    (cd "$DIR" && "$COMPOSE_CMD" "${compose_files[@]}" exec caddy \
      caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile)
}

for attempt in 1 2 3 4 5; do
  if reload_once; then
    echo "[reload-tls-proxy-caddy] Caddy reloaded OK."
    exit 0
  fi
  [[ "$attempt" -lt 5 ]] && sleep 1
done

echo "[reload-tls-proxy-caddy] ERROR: caddy reload failed after retries (is tls-proxy up?)." >&2
exit 1
