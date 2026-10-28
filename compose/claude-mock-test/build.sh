#!/usr/bin/env bash
# Verify the vendored site/ is self-consistent, then build the container image.
# Runs on the TARGET (beeblebox), which has no node — the real test suite and bank check
# run in sync-site.sh on the authoring machine. This is the last-line integrity check that
# a truncated or stale sync doesn't reach a container.
# Args after this script's argv are passed to "podman-compose build" (e.g. --no-cache).
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"

cd "$STACK_DIR"
compose_files=(-f compose.yaml)
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)

# MOCK_TEST_SITE: directory holding the site to publish (default ./site, the tracked fallback).
# Any other directory is copied to .build/site (git-ignored) first, because the image build
# context is this stack directory; Dockerfile reads the site from SITE_DIR (a build arg).
SITE_DIR="${MOCK_TEST_SITE:-$STACK_DIR/site}"
[[ -d "$SITE_DIR" ]] || {
  echo "ERROR: MOCK_TEST_SITE is not a directory: $SITE_DIR" >&2
  exit 1
}
SITE_DIR="$(cd "$SITE_DIR" && pwd -P)"
[[ -f "$SITE_DIR/index.html" ]] || {
  echo "ERROR: site/index.html missing. Run compose/claude-mock-test/sync-site.sh on the authoring machine first." >&2
  exit 1
}

echo "[build claude-mock-test] Checking every asset referenced by site/index.html exists..."
missing=0
refs="$(grep -oE '(src|href)="[^"]+"' "$SITE_DIR/index.html" | sed -E 's/^(src|href)="//; s/"$//')"
count=0
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  # Only local relative references; skip absolute URLs and anchors.
  case "$ref" in
    http://* | https://* | //* | \#* | data:*) continue ;;
  esac
  count=$((count + 1))
  if [[ ! -f "$SITE_DIR/$ref" ]]; then
    echo "  MISSING: $ref" >&2
    missing=$((missing + 1))
  fi
done <<< "$refs"

if [[ "$missing" -ne 0 ]]; then
  echo "ERROR: $missing asset(s) referenced by index.html are absent from site/. Re-run sync-site.sh." >&2
  exit 1
fi
echo "[build claude-mock-test] OK - $count referenced asset(s) present."

# The course PDF and the extracted notes are the authoring source, not deployable content.
if find "$SITE_DIR" -type f \( -iname '*.pdf' -o -name 'notes.txt' \) | grep -q .; then
  echo "ERROR: site/ contains source material that must not be published (PDF or notes.txt)." >&2
  exit 1
fi

if [[ -f "$SITE_DIR/version.txt" ]]; then
  echo "[build claude-mock-test] Building:"
  sed 's/^/  /' "$SITE_DIR/version.txt"
fi

if [[ "$SITE_DIR" == "$(pwd -P)/site" ]]; then
  export MOCK_TEST_SITE_CTX="site"
else
  rm -rf "$STACK_DIR/.build/site"
  mkdir -p "$STACK_DIR/.build"
  cp -a "$SITE_DIR" "$STACK_DIR/.build/site"
  export MOCK_TEST_SITE_CTX=".build/site"
fi

echo "[build claude-mock-test] Building container image (site: $MOCK_TEST_SITE_CTX)..."
"$COMPOSE_CMD" "${compose_files[@]}" build "$@"
