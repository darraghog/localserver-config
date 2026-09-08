#!/usr/bin/env bash
# Build gate for the gqldb stack. Proves the things the stack silently depends on before a
# container is ever created, because each of them fails late and confusingly otherwise:
#   - the vendor-supplied .deb is present and is the file we recorded (there is no apt
#     source and the upstream repo is private, so it cannot be re-fetched);
#   - the server binary pin has not been edited away from the hash that was verified;
#   - grpcurl is actually in the database image - without it the healthcheck can never pass
#     and the container would sit "unhealthy" forever with no obvious cause;
#   - both images run as the unprivileged uid and can write their volumes' mount points.
set -euo pipefail
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME:-/root}/.local/bin:${PATH:-/usr/bin:/bin}"
COMPOSE_CMD="${HOME:-/root}/.local/bin/podman-compose"
cd "$STACK_DIR"

EXPECT_SHA=effc0f301040e25b0e04c1ed21bf484d6bc11ab325ef879913c01cac595139da
if ! grep -qF "$EXPECT_SHA" Dockerfile.gqldb; then
  echo "[build gqldb] ERROR: Dockerfile.gqldb no longer pins $EXPECT_SHA." >&2
  echo "  Re-verify against https://download.ultipa.com/gqldb/v<version>/checksums.sha256" >&2
  echo "  before changing it, and bump GQLDB_VERSION and GQLDB_SHA256 together." >&2
  exit 1
fi

shopt -s nullglob
debs=( *.deb )
shopt -u nullglob
if [[ ${#debs[@]} -eq 0 ]]; then
  echo "[build gqldb] ERROR: no GQLDB Manager .deb in $STACK_DIR." >&2
  echo "  This file is vendor-supplied and gitignored: the upstream GitHub repo is private" >&2
  echo "  and there is no apt source, so the build cannot fetch it. Copy the .deb here." >&2
  exit 1
fi
if [[ ${#debs[@]} -gt 1 ]]; then
  echo "[build gqldb] ERROR: ${#debs[@]} .deb files present; Dockerfile.manager COPYs *.deb" >&2
  printf '  %s\n' "${debs[@]}" >&2
  exit 1
fi

# The .deb's hash is recorded on first build rather than hardcoded, because the file is
# supplied by hand. Once recorded, a silent swap fails the build.
deb="${debs[0]}"
actual="$(sha256sum "$deb" | cut -d' ' -f1)"
if [[ -f manager.deb.sha256 ]]; then
  expected="$(tr -d '[:space:]' < manager.deb.sha256)"
  if [[ "$actual" != "$expected" ]]; then
    echo "[build gqldb] ERROR: $deb does not match manager.deb.sha256." >&2
    echo "  expected $expected" >&2
    echo "  actual   $actual" >&2
    echo "  If this is a deliberate upgrade, update manager.deb.sha256 and README.md." >&2
    exit 1
  fi
  echo "[build gqldb] .deb matches recorded sha256."
else
  echo "$actual" > manager.deb.sha256
  echo "[build gqldb] Recorded $deb sha256 as $actual (manager.deb.sha256)."
fi

compose_files=(-f compose.yaml)
[[ -f compose.local.yaml ]] && compose_files+=(-f compose.local.yaml)

echo "[build gqldb] Building images..."
"$COMPOSE_CMD" "${compose_files[@]}" build "$@"

echo "[build gqldb] Smoke-testing localhost/gqldb_gqldb..."
podman run --rm --entrypoint /bin/sh localhost/gqldb_gqldb -c '
  set -e
  sha256sum /usr/local/bin/ultipa-gqldb | grep -q '"$EXPECT_SHA"'
  /usr/local/bin/ultipa-gqldb -version >/dev/null
  command -v grpcurl >/dev/null
  [ "$(id -u)" = 10001 ]
  [ -w /data ] && [ -w /backups ]
'

echo "[build gqldb] Smoke-testing localhost/gqldb_manager..."
podman run --rm --entrypoint /bin/sh localhost/gqldb_manager -c '
  set -e
  [ -f /app/server/dist/index.js ]
  [ -f /app/client/dist/index.html ]
  # Actually dlopen the native module rather than just checking it exists. This is the
  # glibc build that forces a Debian base, and it is supplied by the app.asar.unpacked
  # overlay - so a require() here catches BOTH a musl/glibc mismatch and a silently skipped
  # overlay step, either of which would otherwise surface only when someone first opened
  # the console. Verified to load and export Database/Transaction.
  NM=/app/deps/ultipa-gqldb/platforms/linux-x64/ultipagqldb.node
  node -e "const m = require(process.argv[1]); if (!m.Database) { console.error(\"native module loaded but exports no Database\"); process.exit(1); }" "$NM"
  [ "$(id -u)" = 10001 ]
  [ -w /data ]
'

echo "[build gqldb] OK"
