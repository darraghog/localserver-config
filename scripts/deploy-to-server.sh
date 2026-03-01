#!/usr/bin/env bash
# Deploy this repo to a target and run post-deploy checks.
# Usage: ./scripts/deploy-to-server.sh <env> <target>
#   env:    environment name — selects envs/<env>.env for credentials
#   target: 'local' to deploy on this machine, or a hostname (e.g. darragh-pc)
# Examples:
#   ./scripts/deploy-to-server.sh local local
#   ./scripts/deploy-to-server.sh prod darragh-pc

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${1:-}"
TARGET="${2:-}"

if [[ -z "$ENV_NAME" || -z "$TARGET" ]]; then
  echo "Usage: $(basename "$0") <env> <target>"
  echo "  env:    environment name (selects envs/<env>.env)"
  echo "  target: 'local' or a hostname"
  exit 1
fi

ENV_FILE="$REPO_ROOT/envs/$ENV_NAME.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: env file not found: $ENV_FILE"
  echo "Create it from: cp .env.example envs/$ENV_NAME.env"
  exit 1
fi

REMOTE_PATH="~/localserver-config"

if [[ "$TARGET" == "local" ]]; then
  echo "[deploy] Environment: $ENV_NAME, target: local"
  echo ""

  cp "$ENV_FILE" "$REPO_ROOT/.env"

  echo "[deploy] Running deploy..."
  "$REPO_ROOT/scripts/deploy.sh" --compose-only

  echo ""
  echo "[deploy] Running port checks..."
  "$REPO_ROOT/tests/check-ports.sh"

  echo ""
  echo "[deploy] Running TLS check..."
  "$REPO_ROOT/scripts/check-tls.sh"

else
  echo "[deploy] Environment: $ENV_NAME, target: $TARGET"
  echo "[deploy] Remote: $REMOTE_PATH"
  echo ""

  echo "[deploy] Syncing repo (preserving certs/, excluding envs/)..."
  rsync -avz --delete \
    --exclude='.git' \
    --exclude='certs/' \
    --exclude='.env' \
    --exclude='envs/' \
    --filter='P certs/' \
    "$REPO_ROOT/" "$TARGET:$REMOTE_PATH/"

  echo ""
  echo "[deploy] Copying env file..."
  scp "$ENV_FILE" "$TARGET:$REMOTE_PATH/.env"

  echo ""
  echo "[deploy] Running deploy on $TARGET..."
  ssh "$TARGET" "cd $REMOTE_PATH && chmod +x scripts/*.sh && ./scripts/deploy.sh --compose-only"

  echo ""
  echo "[deploy] Running port checks on $TARGET..."
  ssh "$TARGET" "cd $REMOTE_PATH && ./tests/check-ports.sh"

  echo ""
  echo "[deploy] Running TLS check from local..."
  "$REPO_ROOT/scripts/check-tls.sh" "$TARGET"

  echo ""
  echo "[deploy] Done."
  echo "  Hello-world:  https://$TARGET:8443"
  echo "  n8n:          https://$TARGET:8444"
fi
