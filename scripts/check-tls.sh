#!/usr/bin/env bash
# TLS diagnostic - run on server (darragh-pc)
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { echo "[check] $*"; }
H="$(hostname)"
CERTS="$REPO_ROOT/certs"

log "1. Certs exist?"
[[ -f "$CERTS/server.pem" && -f "$CERTS/server-key.pem" ]] && log "   OK" || { log "   FAIL: run scripts/setup-certs.sh"; exit 1; }

log "2. Caddy running?"
podman ps --format '{{.Names}}' 2>/dev/null | grep -q caddy || { log "   FAIL: cd compose/tls-proxy && podman compose up -d"; exit 1; }
log "   OK"

log "3. Ports 8443, 8444 listening?"
ss -tlnp 2>/dev/null | grep -qE ':844[34]' || { log "   FAIL: restart Caddy"; exit 1; }
log "   OK"

log "4. Backend (hello-world) on 8080?"
curl -s --connect-timeout 2 "http://127.0.0.1:8080/" >/dev/null && log "   OK" || log "   WARN: start hello-world stack"

log "5. Curl https://127.0.0.1:8443/ (localhost, verified)?"
curl -s --cacert "$CERTS/ca.pem" --connect-timeout 3 "https://127.0.0.1:8443/" >/dev/null && log "   OK" || { log "   FAIL"; exit 1; }

log "6. Curl https://${H}:8443/ (hostname, verified)?"
curl -s --cacert "$CERTS/ca.pem" --connect-timeout 3 "https://${H}:8443/" >/dev/null && log "   OK" || log "   WARN: hostname may not be in cert (re-run setup-certs.sh with this hostname)"

log "7. From other machine: Trust certs/ca.pem on client. See docs/tls.md"
