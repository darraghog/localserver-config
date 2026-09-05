#!/usr/bin/env bash
# Deploy or update LiteLLM on this machine (local) or a remote server (prod).
#
# Usage:
#   ./scripts/deploy-litellm.sh [--config-only] [local | prod <hostname>]
#
# Modes:
#   (default)      Full redeploy: pull new image, restart container, reload Caddy
#   --config-only  Push config.yaml and restart container only — no image pull, no rsync
#
# Targets:
#   local  (default)  run on this machine
#   prod <hostname>   SSH to <hostname>. Falls back to $LITELLM_PROD_HOST (may be set
#                     in .env) when the positional host is omitted.
#
# Examples:
#   ./scripts/deploy-litellm.sh                        # full redeploy on this machine
#   ./scripts/deploy-litellm.sh prod myserver          # full redeploy on myserver
#   ./scripts/deploy-litellm.sh --config-only          # push config + restart locally
#   ./scripts/deploy-litellm.sh --config-only prod myserver

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROD_REMOTE_PATH="~/localserver-config"
CONTAINER="litellm_litellm_1"

# LiteLLM publishes on the host-internal address, not loopback (p-open-east-west), so
# health checks must target it rather than localhost. Sourced from .env; the fallback keeps
# the script usable before .env is populated.
[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a
# Prod target host: positional arg wins, else $LITELLM_PROD_HOST (possibly from .env).
# No default — this script must not hardcode a deployment host.
PROD_HOST="${LITELLM_PROD_HOST:-}"

HOST_INTERNAL_IP="${HOST_INTERNAL_IP:-10.255.255.254}"
LITELLM_URL="http://${HOST_INTERNAL_IP}:4000"
CONFIG_LOCAL="$REPO_ROOT/compose/litellm/config.yaml"
CONFIG_REMOTE="$PROD_REMOTE_PATH/compose/litellm/config.yaml"

CONFIG_ONLY=0
TARGET="local"

usage() {
  echo "Usage: $(basename "$0") [--config-only] [local | prod <hostname>]" >&2
  echo "  --config-only    Push config.yaml and restart container (no image pull)" >&2
  echo "  local            Deploy to this machine (default)" >&2
  echo "  prod <hostname>  Deploy to <hostname> via SSH (or set LITELLM_PROD_HOST)" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-only) CONFIG_ONLY=1; shift ;;
    local)         TARGET="local"; shift ;;
    prod)          TARGET="prod"; shift
                   # Optional positional host right after "prod".
                   if [[ $# -gt 0 && "$1" != -* ]]; then PROD_HOST="$1"; shift; fi ;;
    -h|--help)     usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ "$TARGET" == "prod" && -z "$PROD_HOST" ]]; then
  echo "Error: prod needs a target host." >&2
  echo "  ./scripts/deploy-litellm.sh prod <hostname>   (or set LITELLM_PROD_HOST)" >&2
  exit 1
fi

log() { echo "[deploy-litellm] $*"; }

# Retry curl health check up to 3 times with 3s sleep.
wait_healthy_local() {
  local code
  for _try in 1 2 3; do
    code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 \
      "${LITELLM_URL}/health/liveliness" 2>/dev/null || true)"
    [[ "$code" == "200" ]] && { log "OK — LiteLLM healthy at ${LITELLM_URL}"; return 0; }
    [[ "$_try" -lt 3 ]] && sleep 3
  done
  log "WARN: health check returned HTTP ${code:-000}; container may still be starting"
}

wait_healthy_remote() {
  log "Checking health on $PROD_HOST..."
  # HOST_INTERNAL_IP must resolve on the REMOTE host, so source the remote .env inside the
  # ssh payload rather than interpolating this machine's value.
  ssh "$PROD_HOST" "
    set -a; [ -f $PROD_REMOTE_PATH/.env ] && . $PROD_REMOTE_PATH/.env; set +a
    url=\"http://\${HOST_INTERNAL_IP:-10.255.255.254}:4000\"
    for _try in 1 2 3; do
      code=\$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 \
        \"\$url/health/liveliness\" 2>/dev/null || true)
      [ \"\$code\" = '200' ] && { echo '[deploy-litellm] OK — LiteLLM healthy on $PROD_HOST'; exit 0; }
      [ \"\$_try\" -lt 3 ] && sleep 3
    done
    echo '[deploy-litellm] WARN: health check returned HTTP '\"\$code\"'; container may still be starting'
  "
}

# ── config-only ──────────────────────────────────────────────────────────────

config_only_local() {
  log "Config-only update (local)..."
  log "Restarting $CONTAINER..."
  podman restart "$CONTAINER"
  wait_healthy_local
  echo ""
  echo "  LiteLLM:  ${LITELLM_URL}"
  echo ""
  log "Done."
}

config_only_remote() {
  log "Config-only update → $PROD_HOST..."
  log "Copying config.yaml..."
  scp "$CONFIG_LOCAL" "$PROD_HOST:$CONFIG_REMOTE"
  log "Restarting $CONTAINER on $PROD_HOST..."
  ssh "$PROD_HOST" "podman restart $CONTAINER"
  wait_healthy_remote
  echo ""
  echo "  LiteLLM:  https://$PROD_HOST:8447/ui"
  echo "  UI login: \$LITELLM_UI_USERNAME / WSL password (see envs/prod.env)"
  echo ""
  log "Done."
}

# ── full redeploy ─────────────────────────────────────────────────────────────

full_local() {
  log "Full redeploy (local)..."
  "$REPO_ROOT/scripts/deploy-service.sh" local local litellm
  echo ""
  echo "  LiteLLM:  ${LITELLM_URL}  https://$(hostname):8447/ui"
  echo "  UI login: \$LITELLM_UI_USERNAME / WSL password"
  echo "  Set password: ./scripts/litellm-sync-wsl-ui-env.sh dev"
  echo ""
}

full_remote() {
  log "Full redeploy → $PROD_HOST..."
  "$REPO_ROOT/scripts/deploy-service.sh" prod "$PROD_HOST" litellm
  echo ""
  echo "  LiteLLM:  https://$PROD_HOST:8447/ui"
  echo "  UI login: \$LITELLM_UI_USERNAME / WSL password (see envs/prod.env)"
  echo ""
}

# ── dispatch ──────────────────────────────────────────────────────────────────

case "$TARGET" in
  local)
    [[ "$CONFIG_ONLY" -eq 1 ]] && config_only_local || full_local
    ;;
  prod)
    [[ "$CONFIG_ONLY" -eq 1 ]] && config_only_remote || full_remote
    ;;
esac
