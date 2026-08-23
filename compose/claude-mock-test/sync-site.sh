#!/usr/bin/env bash
# Refresh compose/claude-mock-test/site/ from the mock-test source repo.
#
# Run this on the AUTHORING machine, before deploying — beeblebox has no node, so the
# test suite and bank checker can only run here. deploy-service.sh rsyncs this repo only,
# which is why the app has to be vendored into site/ at all.
#
# Usage: ./compose/claude-mock-test/sync-site.sh [--allow-dirty]
# Env:   MOCK_TEST_SRC  source repo (default: $HOME/dev/claude/mock-test)
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_DIR="$STACK_DIR/site"
SRC="${MOCK_TEST_SRC:-$HOME/dev/claude/mock-test}"
ALLOW_DIRTY=0

for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}" >&2
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$arg'" >&2
      exit 1
      ;;
  esac
done

log() { echo "[sync-site] $*"; }

[[ -d "$SRC" ]] || {
  echo "ERROR: source repo not found: $SRC (set MOCK_TEST_SRC)" >&2
  exit 1
}
[[ -f "$SRC/index.html" ]] || {
  echo "ERROR: $SRC does not look like the mock-test repo (no index.html)" >&2
  exit 1
}

if [[ "$ALLOW_DIRTY" -eq 0 ]]; then
  if [[ -n "$(git -C "$SRC" status --porcelain 2>/dev/null)" ]]; then
    echo "ERROR: $SRC has uncommitted changes. Commit them, or pass --allow-dirty." >&2
    exit 1
  fi
fi

command -v node >/dev/null || {
  echo "ERROR: node not found. Run this on the authoring machine, not the server." >&2
  exit 1
}

log "Running the mock-test suite in $SRC ..."
(cd "$SRC" && node --test)   # bare form: 'node --test test/' misresolves on Node 24.x

log "Checking bank integrity ..."
(cd "$SRC" && node tools/check-bank.js)

# Allowlist, deliberately not an exclude list: the source repo also holds the copyrighted
# course PDF, notes.txt, docs/ and .superpowers/, none of which may ever be published.
# An allowlist fails closed when the source gains a new file; an exclude list fails open.
log "Copying the runtime files into site/ ..."
rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR/questions"
for f in index.html styles.css bank.js engine.js ui.js; do
  [[ -f "$SRC/$f" ]] || {
    echo "ERROR: missing expected source file: $SRC/$f" >&2
    exit 1
  }
  cp "$SRC/$f" "$SITE_DIR/$f"
done
shopt -s nullglob
qs=("$SRC"/questions/*.js)
shopt -u nullglob
[[ ${#qs[@]} -gt 0 ]] || {
  echo "ERROR: no question files found in $SRC/questions/" >&2
  exit 1
}
cp "${qs[@]}" "$SITE_DIR/questions/"

sha="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
branch="$(git -C "$SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
dirty=""
[[ -n "$(git -C "$SRC" status --porcelain 2>/dev/null)" ]] && dirty=" (dirty)"
cat > "$SITE_DIR/version.txt" <<VER
source: $SRC
commit: $sha$dirty
branch: $branch
synced: $(date -u +%Y-%m-%dT%H:%M:%SZ)
questions: ${#qs[@]} domain files
VER

log "site/ now holds $(find "$SITE_DIR" -type f | wc -l) files ($(du -sh "$SITE_DIR" | cut -f1))"
log "Synced $sha$dirty from $branch. Next: commit, then"
log "  ./scripts/deploy-service.sh --verify prod beeblebox claude-mock-test tls-proxy"
