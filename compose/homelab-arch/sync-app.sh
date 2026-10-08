#!/usr/bin/env bash
# Vendor the homelab-arch application into ./app for the host build. Run on the WORKSTATION
# before scripts/deploy-service.sh, which rsyncs ./app to the server with the rest of the repo.
#
# Copies `git archive <ref>` of the app repository: committed files only, so .env,
# frontend/.env.local, .venv, node_modules, data/*.db and .superpowers/ can never be vendored.
#
# Usage: compose/homelab-arch/sync-app.sh [<ref>]      (default ref: main)
#   HLA_SOURCE_REPO   the app repository (default: ~/dev/homelab-arch)
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${HLA_SOURCE_REPO:-$HOME/dev/homelab-arch}"
if [[ $# -gt 1 || "${1:-}" == -* ]]; then
  echo "usage: $(basename "$0") [<ref>]   (env HLA_SOURCE_REPO; default ref: main)" >&2
  exit 2
fi
REF="${1:-main}"

if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "[sync-app homelab-arch] ERROR: $REPO is not a git repository (set HLA_SOURCE_REPO)" >&2
  exit 1
fi

if ! COMMIT="$(git -C "$REPO" rev-parse --verify --quiet "${REF}^{commit}")"; then
  echo "[sync-app homelab-arch] ERROR: $REF is not a commit in $REPO" >&2
  exit 1
fi

NEW="$STACK_DIR/app.new"
rm -rf "$NEW"
mkdir "$NEW"
git -C "$REPO" archive --format=tar "$COMMIT" | tar -x -C "$NEW"
for f in .env frontend/.env.local data/proposals.db; do
  if [[ -e "$NEW/$f" ]]; then
    rm -rf "$NEW"
    echo "[sync-app homelab-arch] ERROR: $f is committed in $REPO; refusing to vendor it" >&2
    exit 1
  fi
done
for f in Dockerfile requirements.lock frontend/package-lock.json ontology/ontology.yaml; do
  if [[ ! -f "$NEW/$f" ]]; then
    rm -rf "$NEW"
    echo "[sync-app homelab-arch] ERROR: $COMMIT has no $f; is it a Milestone 6 commit?" >&2
    exit 1
  fi
done
printf '%s %s\n' "$COMMIT" "$REF" >"$NEW/SOURCE_COMMIT"
rm -rf "$STACK_DIR/app"
mv "$NEW" "$STACK_DIR/app"
echo "[sync-app homelab-arch] Vendored $COMMIT ($REF) into compose/homelab-arch/app"
