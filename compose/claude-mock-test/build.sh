#!/usr/bin/env bash
# Verify the site directory named by MOCK_TEST_SITE is self-consistent, then build the image.
# The site is not tracked in this repo: deployd's deploy-mock-test stages the runtime files of a
# claude-mock-test release tag and exports MOCK_TEST_SITE before calling deploy-stack.sh.
# Runs on the TARGET (beeblebox), which has no node, so this is the last-line integrity check
# that a truncated or stale staging doesn't reach a container.
# Args after this script's argv are passed to "podman-compose build" (e.g. --no-cache).
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"

cd "$STACK_DIR"
compose_files=(-f compose.yaml)
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)

# MOCK_TEST_SITE (required): directory holding the site to publish. It is copied to .build/site
# (git-ignored) first, because the image build context is this stack directory; Dockerfile
# reads the site from SITE_DIR (a build arg), which compose.yaml sets from MOCK_TEST_SITE_CTX.
[[ -n "${MOCK_TEST_SITE:-}" && -d "${MOCK_TEST_SITE}" ]] || {
  echo "ERROR: set MOCK_TEST_SITE to the site directory; deploy via deployd's deploy-mock-test." >&2
  exit 1
}
SITE_DIR="$(cd "$MOCK_TEST_SITE" && pwd -P)"
[[ -f "$SITE_DIR/index.html" ]] || {
  echo "ERROR: $SITE_DIR/index.html missing. Re-run deployd's deploy-mock-test." >&2
  exit 1
}

echo "[build claude-mock-test] Checking every asset referenced by index.html exists..."
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
  echo "ERROR: $missing asset(s) referenced by index.html are absent from $SITE_DIR. Re-run deployd's deploy-mock-test." >&2
  exit 1
fi
echo "[build claude-mock-test] OK - $count referenced asset(s) present."

# The course PDF and the extracted notes are the authoring source, not deployable content.
if find "$SITE_DIR" -type f \( -iname '*.pdf' -o -name 'notes.txt' \) | grep -q .; then
  echo "ERROR: $SITE_DIR contains source material that must not be published (PDF or notes.txt)." >&2
  exit 1
fi

if [[ -f "$SITE_DIR/version.txt" ]]; then
  echo "[build claude-mock-test] Building:"
  sed 's/^/  /' "$SITE_DIR/version.txt"
fi

rm -rf "$STACK_DIR/.build/site"
mkdir -p "$STACK_DIR/.build"
cp -a "$SITE_DIR" "$STACK_DIR/.build/site"
export MOCK_TEST_SITE_CTX=".build/site"

echo "[build claude-mock-test] Building container image (site: $MOCK_TEST_SITE_CTX)..."
"$COMPOSE_CMD" "${compose_files[@]}" build "$@"
