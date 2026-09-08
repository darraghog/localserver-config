#!/bin/sh
# Readiness probe for GQLDB. Deliberately more than a TCP or transport-level check.
#
# Two things make this awkward, both verified against the running server:
#   1. gRPC reflection is behind the auth interceptor, so grpcurl cannot resolve ANY method
#      without a session - including SessionService/Login itself. Hence the vendored
#      gqldb.proto and -proto: with it, Login works unauthenticated, as it must.
#   2. gqldb.Health/Check is also behind the interceptor ("missing session ID"), so it
#      cannot be called cold. It returns HEALTH_STATUS_SERVING once a session exists.
#
# Logging in is what makes this readiness rather than liveness: it proves the gRPC server
# is serving AND that RBAC could read the __system__ store. A probe that only proved the
# port was open would let depends_on release the console before the database can answer.
#
# The password is passed on stdin as JSON built by jq, never on argv: a healthcheck command
# is visible in `podman inspect`, and jq also makes the JSON safe for passwords containing
# quotes or backslashes.
set -u
PROTO="-import-path /opt/gqldb -proto gqldb.proto"
ADDR=127.0.0.1:60061

session=$(jq -nc --arg u "${GQLDB_ADMIN_USER:-admin}" --arg p "${GQLDB_RBAC_ADMIN_PASSWORD:-}" \
            '{username:$u,password:$p}' \
          | grpcurl -plaintext $PROTO -d @ -max-time 5 "$ADDR" gqldb.SessionService/Login 2>/dev/null \
          | jq -r '.sessionId // empty')
[ -n "$session" ] || exit 1

status=$(grpcurl -plaintext $PROTO -H "session-id: $session" -d '{}' -max-time 5 \
           "$ADDR" gqldb.Health/Check 2>/dev/null | jq -r '.status // empty')

# Sessions have a TTL of an hour and this runs every 30s, so an un-released session per
# probe would pile up. Best effort - the exit status below is what matters.
grpcurl -plaintext $PROTO -H "session-id: $session" -d '{}' -max-time 5 \
  "$ADDR" gqldb.SessionService/Logout >/dev/null 2>&1 || true

[ "$status" = "HEALTH_STATUS_SERVING" ]
