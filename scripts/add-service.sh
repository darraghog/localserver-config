#!/usr/bin/env bash
# Scaffold a new Podman compose stack (like hello-world / n8n) and register it for deploy.
# Usage: ./scripts/add-service.sh <stack-name> [--port HOST_PORT] [--container-port PORT] [--image IMAGE]
# Example: ./scripts/add-service.sh wiki --port 8090
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_COMPOSE="$REPO_ROOT/scripts/templates/stack-compose.yaml.in"
TEMPLATE_UNIT="$REPO_ROOT/systemd/templates/localserver-stack.service.in"
STACK_ORDER="$REPO_ROOT/compose/stack-order"
[[ -f "$STACK_ORDER" ]] || {
  echo "ERROR: Missing $STACK_ORDER" >&2
  exit 1
}

PUBLISHED_PORT="8090"
CONTAINER_PORT="80"
IMAGE="docker.io/library/nginx:alpine"

usage() {
  echo "Usage: $(basename "$0") <stack-name> [--port HOST_PORT] [--container-port PORT] [--image IMAGE]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
SLUG="$1"
shift

if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: Stack name must be lowercase letters, digits, or hyphen (start with letter or digit)." >&2
  exit 1
fi

case "$SLUG" in
  hello-world|n8n|tls-proxy)
    echo "ERROR: '$SLUG' is a built-in stack; pick another name or edit compose/$SLUG manually." >&2
    exit 1
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PUBLISHED_PORT="${2:?}"
      shift 2
      ;;
    --container-port)
      CONTAINER_PORT="${2:?}"
      shift 2
      ;;
    --image)
      IMAGE="${2:?}"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

STACK_DIR="$REPO_ROOT/compose/$SLUG"
[[ ! -d "$STACK_DIR" ]] || {
  echo "ERROR: compose/$SLUG already exists." >&2
  exit 1
}

[[ -f "$TEMPLATE_COMPOSE" && -f "$TEMPLATE_UNIT" ]] || {
  echo "ERROR: Missing template under scripts/templates/ or systemd/templates/." >&2
  exit 1
}

mkdir -p "$STACK_DIR"
sed \
  -e "s|__STACK__|$SLUG|g" \
  -e "s|__IMAGE__|$IMAGE|g" \
  -e "s|__PUBLISHED_PORT__|$PUBLISHED_PORT|g" \
  -e "s|__CONTAINER_PORT__|$CONTAINER_PORT|g" \
  "$TEMPLATE_COMPOSE" > "$STACK_DIR/compose.yaml"

insert_stack_order() {
  local tmp
  tmp="$(mktemp)"
  if grep -qE '^[[:space:]]*'"$SLUG"'([[:space:]]|$)' "$STACK_ORDER" 2>/dev/null; then
    echo "Stack $SLUG already listed in compose/stack-order"
    rm -f "$tmp"
    return 0
  fi
  awk -v s="$SLUG" '
    BEGIN { inserted = 0 }
    /^[[:space:]]*tls-proxy([[:space:]]|$)/ && !inserted {
      print s
      inserted = 1
    }
    { print }
    END {
      if (!inserted) print s
    }
  ' "$STACK_ORDER" > "$tmp"
  mv "$tmp" "$STACK_ORDER"
}

insert_stack_order

UNIT_OUT="$REPO_ROOT/systemd/user/localserver-${SLUG}.service"
sed -e "s|__STACK__|$SLUG|g" "$TEMPLATE_UNIT" > "$UNIT_OUT"

echo "[add-service] Created compose/$SLUG/compose.yaml"
echo "[add-service] Registered $SLUG in compose/stack-order (before tls-proxy if present)"
echo "[add-service] Wrote systemd/user/localserver-${SLUG}.service (placeholders __REPO_ROOT__ / __HOME__ for bootstrap)"
echo ""
echo "Next steps:"
echo "  1. Re-run host bootstrap to install the new unit (or copy/sed the unit like existing stacks):"
echo "       ./scripts/sudo/bootstrap-host.sh"
echo "  2. Deploy only this stack:"
echo "       ./scripts/deploy-stack.sh $SLUG"
echo "  3. For HTTPS via Caddy, add a :PORT { ... reverse_proxy 127.0.0.1:$PUBLISHED_PORT } block to compose/tls-proxy/Caddyfile, then:"
echo "       ./scripts/deploy-stack.sh tls-proxy"
echo "  4. Optional per-machine overrides: compose/$SLUG/compose.local.yaml (merged by start-stack.sh)"
