#!/usr/bin/env bash
# TLS / Caddy diagnostic (requires certs/server.pem and working tls-proxy).
# Usage: ./scripts/check-tls.sh              # local
#        ./scripts/check-tls.sh <scp-host> [<curl-host>]
#   <scp-host>  — scp(1) destination for certs/ca.pem (e.g. SSH config Host name)
#   <curl-host> — optional; host or IP for http/https curls (default: same as <scp-host>).
#                 Use the LAN IP when DNS resolves to a path that does not reach Caddy on 8443/8444
#                 (typical WSL + Windows: HTTP :8080 works by hostname but HTTPS must use the LAN IP).
#   Env: CHECK_TLS_CURL_HOST overrides <curl-host> when set.
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { echo "[check] $*"; }

trim_arg() {
  local x="$1"
  x="${x//$'\r'/}"
  x="${x#"${x%%[![:space:]]*}"}"
  x="${x%"${x##*[![:space:]]}"}"
  printf '%s' "$x"
}

HOST="$(trim_arg "${1:-}")"
CURL_HOST="$(trim_arg "${CHECK_TLS_CURL_HOST:-${2:-}}")"
[[ -n "$HOST" ]] && [[ -z "$CURL_HOST" ]] && CURL_HOST="$HOST"

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
  log "Remote TLS check (scp: $HOST, curl: $CURL_HOST)"

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

  curl_https() {
    local url="$1"
    local label="$2"
    set +e
    err="$(curl -sS --cacert "$CA_PEM" --connect-timeout 8 "$url" -o /dev/null 2>&1)"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      log "   OK"
      return 0
    fi
    log "   FAIL"
    [[ -n "$err" ]] && log "         $err"
    if echo "$err" | grep -qiE 'timed out|connection refused|Failed to connect|Could not resolve'; then
      log "         TCP: nothing accepted HTTPS (or blocked). WSL+Windows: open/forward 8443 from LAN — docs/NETWORK-CONFIG.md"
      log "         Retry with LAN IP: ./scripts/check-tls.sh $HOST <lan-ip>  (or CHECK_TLS_CURL_HOST=<ip>)"
    elif echo "$err" | grep -qiE 'SSL certificate|certificate verify|unable to get local issuer'; then
      log "         TLS: trust ca.pem or fix cert SANs (include $CURL_HOST); re-run deploy with DEPLOY_CERT_EXTRA_SANS"
    fi
    return "$rc"
  }

  log "1. Curl http://${CURL_HOST}:8080/ (hello-world plain HTTP)?"
  curl -s --connect-timeout 5 "http://${CURL_HOST}:8080/" >/dev/null && log "   OK" || log "   WARN: hello-world may not be running"

  log "2. Curl https://${CURL_HOST}:8443/ (verified with ca.pem)?"
  curl_https "https://${CURL_HOST}:8443/" "8443" || exit 1

  log "3. Curl https://${CURL_HOST}:8444/ (verified with ca.pem)?"
  curl_https "https://${CURL_HOST}:8444/" "8444" || exit 1

  log "4. Curl https://${CURL_HOST}:9443/ (Cockpit, verified with ca.pem)?"
  if curl_https "https://${CURL_HOST}:9443/" "9443"; then
    :
  else
    log "   WARN: Cockpit may not be installed (run scripts/sudo/setup-cockpit.sh on server)"
  fi

  log "All remote TLS checks passed."
fi
