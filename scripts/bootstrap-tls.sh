#!/usr/bin/env bash
# Bootstrap local TLS certs for HTTPS. Creates CA + server cert in certs/
# Prefer: ./scripts/setup-certs.sh (user-facing entry point)
# Usage: ./scripts/bootstrap-tls.sh [ip_or_hostname ...]
# With no args: prompts for server IP and uses hostname + 127.0.0.1 + that IP

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="${REPO_ROOT}/certs"
CA_KEY="${CERTS_DIR}/ca-key.pem"
CA_CERT="${CERTS_DIR}/ca.pem"
SERVER_KEY="${CERTS_DIR}/server-key.pem"
SERVER_CERT="${CERTS_DIR}/server.pem"

log() { echo "[bootstrap-tls] $*"; }

is_ip() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

# Strip CR/whitespace so "192.168.1.1\r" is still classified as IP (IP: SAN), not DNS: (browsers/curl require IP: when using https://<ip>).
normalize_san_token() {
  local x="$1"
  x="${x//$'\r'/}"
  x="${x#"${x%%[![:space:]]*}"}"
  x="${x%"${x##*[![:space:]]}"}"
  printf '%s' "$x"
}

HOSTNAMES=()
if [[ $# -gt 0 ]]; then
  for _arg in "$@"; do
    _t="$(normalize_san_token "$_arg")"
    [[ -n "$_t" ]] && HOSTNAMES+=("$_t")
  done
  # Ensure localhost + 127.0.0.1 for local access
  for need in localhost 127.0.0.1; do
    [[ " ${HOSTNAMES[*]} " == *" $need "* ]] || HOSTNAMES+=("$need")
  done
  log "Using: ${HOSTNAMES[*]}"
else
  HOSTNAMES=("$(normalize_san_token "$(hostname)")" "localhost" "127.0.0.1")
  while true; do
    read -rp "Server IP address (for cert SAN): " SERVER_IP
    SERVER_IP="$(normalize_san_token "$SERVER_IP")"
    if [[ -z "$SERVER_IP" ]]; then
      log "IP required"
      continue
    fi
    if is_ip "$SERVER_IP"; then
      HOSTNAMES+=("$SERVER_IP")
      break
    fi
    log "Invalid IP format. Try again."
  done
  log "Using: ${HOSTNAMES[*]}"
fi

# CN = server IP (first non-127 IP in list)
CN=""
for h in "${HOSTNAMES[@]}"; do
  if is_ip "$h" && [[ "$h" != "127.0.0.1" ]]; then
    CN="$h"
    break
  fi
done
[[ -z "$CN" ]] && CN="${HOSTNAMES[0]}"

command -v openssl &>/dev/null || { log "Install openssl"; exit 1; }

mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

OPENSSL_CNF="$(mktemp)"
trap "rm -f '$OPENSSL_CNF'" EXIT

SAN=""
for h in "${HOSTNAMES[@]}"; do
  if is_ip "$h"; then
    SAN="${SAN}${SAN:+,}IP:${h}"
  else
    SAN="${SAN}${SAN:+,}DNS:${h}"
  fi
done

cat > "$OPENSSL_CNF" << EOF
[req]
distinguished_name = dn
req_extensions = ext
prompt = no
[dn]
CN = localserver
[ext]
subjectAltName = ${SAN}
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF

if [[ ! -f "$CA_KEY" ]]; then
  log "Creating CA..."
  openssl genrsa -out "$CA_KEY" 4096
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 -out "$CA_CERT" \
    -subj "/O=Localserver/OU=CA/CN=Localserver Local CA"
fi

log "Creating server cert..."
openssl genrsa -out "$SERVER_KEY" 2048
openssl req -new -key "$SERVER_KEY" -out server.csr -subj "/O=Localserver/CN=${CN}" -config "$OPENSSL_CNF"
openssl x509 -req -in server.csr -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial \
  -out "$SERVER_CERT" -days 825 -sha256 -extensions ext -extfile "$OPENSSL_CNF"
rm -f server.csr ca.srl
chmod 600 "$CA_KEY" "$SERVER_KEY"

log "Done: certs/server.pem"
echo ""
echo "  CA cert: $CA_CERT"
echo "  Trust on clients: docs/tls.md"
