#!/usr/bin/env bash
# Refresh compose/weather-mcp/ from the weather MCP server's source repo.
#
# Run this on the AUTHORING machine, before deploying — beeblebox has neither uv
# nor Python 3.13, so the test suite can only run here (and again, hermetically,
# inside the image build). deploy-service.sh rsyncs this repo only, which is why
# the app has to be vendored into this directory at all.
#
# Usage: ./compose/weather-mcp/sync-app.sh [--allow-dirty]
# Env:   WEATHER_SRC  source repo (default: $HOME/dev/claude/weather)
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${WEATHER_SRC:-$HOME/dev/claude/weather}"
ALLOW_DIRTY=0

for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -h|--help)
      sed -n '2,10p' "${BASH_SOURCE[0]}" >&2
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$arg'" >&2
      exit 1
      ;;
  esac
done

log() { echo "[sync-app] $*"; }

[[ -d "$SRC" ]] || {
  echo "ERROR: source repo not found: $SRC (set WEATHER_SRC)" >&2
  exit 1
}
[[ -f "$SRC/unified_server.py" ]] || {
  echo "ERROR: $SRC does not look like the weather repo (no unified_server.py)" >&2
  exit 1
}

# A dirty tree means version.txt would record a commit that doesn't describe what
# actually shipped.
if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  if [[ -n "$(git -C "$SRC" status --porcelain)" ]]; then
    echo "ERROR: $SRC has uncommitted changes. Commit them, or pass --allow-dirty." >&2
    git -C "$SRC" status --short >&2
    exit 1
  fi
fi

log "Running the source repo's test suite..."
(cd "$SRC" && uv run pytest -q) || {
  echo "ERROR: tests failed in $SRC — refusing to vendor a broken tree." >&2
  exit 1
}

# Allowlist, not an exclude list: an allowlist fails closed when the source gains
# a new file, an exclude list fails open. .env and .oauth_store.json are never in
# it — one holds the bearer secret, the other registered OAuth clients and
# refresh tokens.
FILES=(
  unified_server.py
  weather.py
  cities.py
  oauth_provider.py
  web_server.py
  conftest.py
  pyproject.toml
  uv.lock
  .python-version
  Dockerfile
  .containerignore
)

log "Copying runtime files..."
for f in "${FILES[@]}"; do
  [[ -f "$SRC/$f" ]] || { echo "ERROR: missing from source: $f" >&2; exit 1; }
  cp -p "$SRC/$f" "$STACK_DIR/$f"
done

# The image build runs pytest, so the tests have to come along too.
shopt -s nullglob
TESTS=("$SRC"/test_*.py)
shopt -u nullglob
[[ ${#TESTS[@]} -gt 0 ]] || { echo "ERROR: no test_*.py found in $SRC" >&2; exit 1; }
for t in "${TESTS[@]}"; do cp -p "$t" "$STACK_DIR/$(basename "$t")"; done

rm -rf "$STACK_DIR/templates"
mkdir -p "$STACK_DIR/templates"
cp -p "$SRC/templates/index.html" "$STACK_DIR/templates/index.html"

# Fail closed if a secret ever sneaks through.
for forbidden in .env .env.local .oauth_store.json; do
  [[ ! -e "$STACK_DIR/$forbidden" ]] || {
    echo "ERROR: $forbidden must never be vendored — remove it from $STACK_DIR" >&2
    exit 1
  }
done

COUNT=$(( ${#FILES[@]} + ${#TESTS[@]} + 1 ))
cat > "$STACK_DIR/version.txt" <<EOF
source:  $SRC
commit:  $(git -C "$SRC" rev-parse HEAD)$([[ -n "$(git -C "$SRC" status --porcelain)" ]] && echo " (dirty)")
branch:  $(git -C "$SRC" rev-parse --abbrev-ref HEAD)
synced:  $(date -u +%Y-%m-%dT%H:%M:%SZ)
files:   $COUNT
EOF

log "Synced $COUNT file(s):"
sed 's/^/  /' "$STACK_DIR/version.txt"
log "Next: ./scripts/deploy-service.sh --verify prod beeblebox weather-mcp tls-proxy"
