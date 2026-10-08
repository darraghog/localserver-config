#!/usr/bin/env bash
# Build the homelab-arch image from the source vendored in ./app by sync-app.sh.
# Called by scripts/build-stack.sh during a deploy. Args are passed to "podman-compose build"
# (e.g. --no-cache). The image built before this one is kept as :previous for a rollback.
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"
IMAGE=localhost/homelab-arch_app

cd "$STACK_DIR"
compose_files=(-f compose.yaml)
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)

if [[ ! -f app/Dockerfile || ! -f app/SOURCE_COMMIT ]]; then
  echo "[build homelab-arch] ERROR: no vendored source in compose/homelab-arch/app." >&2
  echo "[build homelab-arch] On the workstation run compose/homelab-arch/sync-app.sh, then deploy." >&2
  exit 1
fi
echo "[build homelab-arch] Source: $(cat app/SOURCE_COMMIT)"

OLD_ID=""
if podman image exists "$IMAGE:latest"; then
  OLD_ID="$(podman image inspect -f '{{.Id}}' "$IMAGE:latest")"
fi

echo "[build homelab-arch] Building container image..."
"$COMPOSE_CMD" "${compose_files[@]}" build "$@"

# Tag :previous only after a successful build, and only if the build produced a different
# image: a failed or identical rebuild must not clobber the older rollback target.
NEW_ID="$(podman image inspect -f '{{.Id}}' "$IMAGE:latest")"
if [[ -n "$OLD_ID" && "$OLD_ID" != "$NEW_ID" ]]; then
  podman tag "$OLD_ID" "$IMAGE:previous"
  echo "[build homelab-arch] Kept the replaced image as $IMAGE:previous (rollback)"
fi
