#!/usr/bin/env bash
# Deploy this repo to darragh-pc and run deploy.sh there.
# Usage: ./scripts/deploy-to-server.sh [user@]host [remote-path]
# Example: ./scripts/deploy-to-server.sh darragh-pc

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-darragh-pc}"
REMOTE_PATH="${2:-~/localserver-config}"

echo "[deploy-to-server] Target: $TARGET"
echo "[deploy-to-server] Remote: $REMOTE_PATH"
echo ""

echo "[deploy-to-server] Syncing (preserving certs/)..."
rsync -avz --delete \
  --exclude='.git' \
  --exclude='certs/' \
  --filter='P certs/' \
  "$REPO_ROOT/" "$TARGET:$REMOTE_PATH/"

echo ""
echo "[deploy-to-server] Running deploy on $TARGET..."
ssh "$TARGET" "cd '$REMOTE_PATH' && chmod +x scripts/*.sh && ./scripts/deploy.sh --compose-only"

echo ""
echo "[deploy-to-server] Done."
echo "  Hello-world:  https://<host>:8443"
echo "  n8n:          https://<host>:8444"
