#!/usr/bin/env bash
# TLS diagnostic
# Usage: ./scripts/check-tls.sh              # local (on darragh-pc)
#        ./scripts/check-tls.sh darragh-pc   # remote (from darragh-laptop)
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { echo "[check] $*"; }

HOST="${1:-}"

if [[ -z "$HOST" ]]; then
  # --- Local mode ---
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

else
  # --- Remote mode ---
  log "Remote TLS check against $HOST"

  # Always fetch ca.pem from the remote (local certs/ belongs to this machine's deployment)
  TMP_DIR="$(mktemp -d)"
  CA_PEM="$TMP_DIR/ca.pem"
  log "   Fetching ca.pem from $HOST..."
  if ! scp "$HOST:~/localserver-config/certs/ca.pem" "$CA_PEM" 2>/dev/null; then
    log "   FAIL: could not fetch ca.pem from $HOST:~/localserver-config/certs/ca.pem"
    log "         Run scripts/setup-certs.sh on the server first."
    rm -rf "$TMP_DIR"
    exit 1
  fi

  trap 'rm -rf "$TMP_DIR"' EXIT

  log "1. Curl http://$HOST:8080/ (hello-world plain HTTP)?"
  curl -s --connect-timeout 3 "http://$HOST:8080/" >/dev/null && log "   OK" || log "   WARN: hello-world may not be running"

  log "2. Curl https://$HOST:8443/ (verified with ca.pem)?"
  curl -s --cacert "$CA_PEM" --connect-timeout 3 "https://$HOST:8443/" >/dev/null && log "   OK" || { log "   FAIL"; exit 1; }

  log "3. Curl https://$HOST:8444/ (verified with ca.pem)?"
  curl -s --cacert "$CA_PEM" --connect-timeout 3 "https://$HOST:8444/" >/dev/null && log "   OK" || { log "   FAIL"; exit 1; }

  log "All remote TLS checks passed."
fi
