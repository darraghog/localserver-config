#!/usr/bin/env bash
# Run Python unit tests in a local venv, then build the container image.
# Args after this script's argv are passed to "podman-compose build" (e.g. --no-cache).
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"

cd "$STACK_DIR"
compose_files=(-f compose.yaml)
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)

echo "[build tic-tac-toe] Running unit tests..."
BUILD_DIR="$STACK_DIR/.build"
rm -rf "$BUILD_DIR"
python3 -m venv "$BUILD_DIR/venv"
# shellcheck disable=SC1090
source "$BUILD_DIR/venv/bin/activate"
pip install -q -r requirements.txt -r requirements-dev.txt
pytest -q tests/
deactivate

echo "[build tic-tac-toe] Building container image..."
"$COMPOSE_CMD" "${compose_files[@]}" build "$@"
