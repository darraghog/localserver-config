#!/usr/bin/env bash
# Verify the vendored source is self-consistent, then build the container image.
# Runs on the TARGET (beeblebox), which has neither uv nor Python 3.13 — the real
# test suite runs in sync-app.sh on the authoring machine and again inside the
# image build. This is the last-line integrity check that a truncated or stale
# sync doesn't reach a container.
# Args after this script's argv are passed to "podman-compose build" (e.g. --no-cache).
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"

cd "$STACK_DIR"
compose_files=(-f compose.yaml)
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)

for required in version.txt uv.lock pyproject.toml Dockerfile unified_server.py \
                weather.py cities.py oauth_provider.py templates/index.html; do
  [[ -f "$required" ]] || {
    echo "ERROR: $required missing. Run compose/weather-mcp/sync-app.sh on the authoring machine first." >&2
    exit 1
  }
done

# The image build runs pytest; without the tests the build would fail confusingly.
shopt -s nullglob
tests=(test_*.py)
shopt -u nullglob
[[ ${#tests[@]} -gt 0 ]] || {
  echo "ERROR: no test_*.py vendored — the image build's pytest gate would fail. Re-run sync-app.sh." >&2
  exit 1
}

# Secrets must never reach a build context.
for forbidden in .env .env.local .oauth_store.json; do
  [[ ! -e "$forbidden" ]] || {
    echo "ERROR: $forbidden is present in the stack dir and must not be built into an image." >&2
    exit 1
  }
done

echo "[build weather-mcp] Building:"
sed 's/^/  /' version.txt

echo "[build weather-mcp] Building container image (pytest runs inside the build)..."
"$COMPOSE_CMD" "${compose_files[@]}" build "$@"
