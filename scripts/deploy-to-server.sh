#!/usr/bin/env bash
# Deploy this repo to a target: sync, TLS certs, Podman compose stacks, checks.
# For one or more stacks only (no cert regen / full stack-order), use scripts/deploy-service.sh.
# Cockpit is not included — use scripts/sudo/deploy-cockpit.sh when needed.
# Usage: ./scripts/deploy-to-server.sh <env> <target> [<ssh-port>]
#   env:    environment name — selects envs/<env>.env for credentials
#   target: 'local' or an SSH hostname (TLS check / URLs when prod + certs)
#   ssh-port: optional; non-default SSH port for rsync/scp/ssh (same as DEPLOY_SSH_PORT).
# If <target> is this machine (hostname match, loopback DNS, or DEPLOY_SSH_DEST is local/LAN-IP of self),
# the script deploys like "local" — no rsync/ssh.
# Full TLS/Caddy port checks and check-tls.sh run only for env **prod** when certs/server.pem exists.
# Examples:
#   ./scripts/deploy-to-server.sh local local
#   ./scripts/deploy-to-server.sh prod <hostname> [<ssh-port>]
#   DEPLOY_SSH_DEST=user@<addr> ./scripts/deploy-to-server.sh <env> <hostname>
# Default SSH port is 22 when <ssh-port> is omitted — only pass 2222 (or DEPLOY_SSH_PORT) if sshd listens there.
# Remote TLS: setup-certs includes <target> (host part after user@) in SANs. Optional: DEPLOY_CERT_EXTRA_SANS="ip name ..."
# When prod, the first IPv4 in DEPLOY_CERT_EXTRA_SANS is passed to check-tls as the HTTPS curl host (LAN IP) while scp still uses <target>.
# Override: CHECK_TLS_CURL_HOST=<host-or-ip> ./scripts/deploy-to-server.sh ...

set -e

ssh_port_hint() {
  echo "[deploy] If you saw 'connection refused', sshd on the remote host is probably not on port ${SSH_PORT:-22}." >&2
  echo "  On the server: ss -tlnp | grep -E 'sshd|ssh'" >&2
  echo "  Try default port 22 (omit the third argument), e.g.:" >&2
  echo "  DEPLOY_SSH_DEST=user@<addr> \"$REPO_ROOT/scripts/deploy-to-server.sh\" $ENV_NAME $TARGET" >&2
  [[ -n "$SSH_PORT" ]] && [[ "$SSH_PORT" != "22" ]] && echo "  You used port $SSH_PORT — try 22 if the remote sshd uses the default." >&2
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${1:-}"
TARGET="${2:-}"
SSH_PORT="${3:-${DEPLOY_SSH_PORT:-}}"
SSH_DEST="${DEPLOY_SSH_DEST:-$TARGET}"

if [[ -z "$ENV_NAME" || -z "$TARGET" ]]; then
  echo "Usage: $(basename "$0") <env> <target> [<ssh-port>]"
  echo "  env:        environment name (selects envs/<env>.env)"
  echo "  target:     'local' or an SSH hostname (TLS check / URLs when prod + certs)"
  echo "  ssh-port:   optional SSH port (or set DEPLOY_SSH_PORT)"
  echo "  DEPLOY_SSH_DEST=user@host  when DNS/hosts for <target> is wrong (skipped if target is this machine)"
  exit 1
fi

SSH_PORT_ARGS=()
SCP_PORT_ARGS=()
RSYNC_SSH=()
if [[ -n "$SSH_PORT" ]]; then
  SSH_PORT_ARGS=(-p "$SSH_PORT")
  SCP_PORT_ARGS=(-P "$SSH_PORT")
  RSYNC_SSH=(-e "ssh -p $SSH_PORT")
fi

ENV_FILE="$REPO_ROOT/envs/$ENV_NAME.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: env file not found: $ENV_FILE"
  echo "Create it from: cp .env.example envs/$ENV_NAME.env"
  exit 1
fi

REMOTE_PATH="~/localserver-config"

# So DEPLOY_CERT_EXTRA_SANS dotted quads become IP: SAN entries (not DNS:) after trim — see bootstrap-tls.sh normalize_san_token.
# shellcheck source=scripts/lib/deploy-target.sh
source "$REPO_ROOT/scripts/lib/deploy-target.sh"

# Application ports (8080, 5678) always; TLS/Caddy/Cockpit ports + check-tls only for prod with server.pem.
post_deploy_checks_local() {
  echo ""
  echo "[deploy] Running port checks (application ports)..."
  "$REPO_ROOT/tests/check-ports.sh" --core-only

  if [[ "$ENV_NAME" != "prod" ]]; then
    echo "[deploy] Skip TLS/Caddy checks (not prod)."
    return 0
  fi
  if [[ ! -f "$REPO_ROOT/certs/server.pem" ]]; then
    echo "[deploy] Skip TLS/Caddy checks (prod but no certs/server.pem)."
    return 0
  fi

  echo ""
  echo "[deploy] Running port checks (TLS proxy and Cockpit)..."
  "$REPO_ROOT/tests/check-ports.sh"
  echo ""
  echo "[deploy] Running TLS check..."
  "$REPO_ROOT/scripts/check-tls.sh"
}

post_deploy_checks_remote() {
  echo ""
  echo "[deploy] Running application port checks on $SSH_DEST..."
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && ./tests/check-ports.sh --core-only"

  if [[ "$ENV_NAME" != "prod" ]]; then
    echo "[deploy] Skip TLS/Caddy checks (not prod)."
    return 0
  fi
  if ! ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && test -f certs/server.pem"; then
    echo "[deploy] Skip TLS/Caddy checks (prod but remote has no certs/server.pem)."
    return 0
  fi

  echo ""
  echo "[deploy] Running port checks (TLS proxy and Cockpit) on $SSH_DEST..."
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && ./tests/check-ports.sh"
  echo ""
  echo "[deploy] Running TLS check from local..."
  curl_tls_host="${CHECK_TLS_CURL_HOST:-}"
  if [[ -z "$curl_tls_host" ]]; then
    for tok in ${DEPLOY_CERT_EXTRA_SANS:-}; do
      tok="$(trim_cert_token "$tok")"
      [[ -z "$tok" ]] && continue
      if [[ "$tok" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        curl_tls_host="$tok"
        break
      fi
    done
  fi
  if [[ -n "$curl_tls_host" ]]; then
    echo "[deploy] HTTPS curls use $curl_tls_host (CHECK_TLS_CURL_HOST or first IPv4 in DEPLOY_CERT_EXTRA_SANS); scp still uses $TARGET"
    "$REPO_ROOT/scripts/check-tls.sh" "$TARGET" "$curl_tls_host"
  else
    "$REPO_ROOT/scripts/check-tls.sh" "$TARGET"
  fi
}

run_local_deploy() {
  cp "$ENV_FILE" "$REPO_ROOT/.env"

  echo "[deploy] Running deploy..."
  "$REPO_ROOT/scripts/deploy.sh"

  post_deploy_checks_local
}

url_host_for_messages() {
  if [[ "$TARGET" == "local" ]]; then
    hostname
  else
    echo "$TARGET"
  fi
}

if deploy_target_is_this_host; then
  echo "[deploy] Environment: $ENV_NAME, target: $TARGET"
  if [[ "$TARGET" != "local" ]]; then
    echo "[deploy] Target is this machine — local deploy (no ssh/rsync)."
  fi
  echo ""

  run_local_deploy

  uh="$(url_host_for_messages)"
  echo ""
  echo "[deploy] Done."
  echo "  Hello-world:  https://${uh}:8443"
  echo "  n8n:          https://${uh}:8444"
  echo "  Cockpit:      ./scripts/sudo/deploy-cockpit.sh local  (separate; https://${uh}:9443)"

else
  echo "[deploy] Environment: $ENV_NAME, target: $TARGET"
  echo "[deploy] Remote: $REMOTE_PATH"
  [[ -n "$SSH_PORT" ]] && echo "[deploy] SSH port: $SSH_PORT"
  [[ "$SSH_DEST" != "$TARGET" ]] && echo "[deploy] SSH connect as: $SSH_DEST"
  echo ""

  echo "[deploy] Syncing repo (preserving certs/, excluding envs/)..."
  if ! rsync "${RSYNC_SSH[@]}" -avz --delete \
    --exclude='.git' \
    --exclude='certs/' \
    --exclude='.env' \
    --exclude='envs/' \
    --filter='P certs/' \
    "$REPO_ROOT/" "$SSH_DEST:$REMOTE_PATH/"; then
    ssh_port_hint
    exit 1
  fi

  echo ""
  echo "[deploy] Copying env file..."
  scp "${SCP_PORT_ARGS[@]}" "$ENV_FILE" "$SSH_DEST:$REMOTE_PATH/.env"

  echo ""
  echo "[deploy] Regenerating server cert (hostname, .local, first routable IP, deploy target SANs)..."
  cert_san_host="$(trim_cert_token "${TARGET#*@}")"
  extra_sans_q=""
  if [[ -n "${DEPLOY_CERT_EXTRA_SANS:-}" ]]; then
    for san_tok in $DEPLOY_CERT_EXTRA_SANS; do
      san_tok="$(trim_cert_token "$san_tok")"
      [[ -z "$san_tok" ]] && continue
      extra_sans_q+=" $(printf %q "$san_tok")"
    done
  fi
  # shellcheck disable=SC2029
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && ./scripts/setup-certs.sh \$(hostname) \$(hostname).local \$(hostname -I | awk '{print \$1}') $(printf %q "$cert_san_host")$extra_sans_q"
  echo "[deploy] Remote server.pem subjectAltName:"
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && openssl x509 -in certs/server.pem -noout -ext subjectAltName 2>/dev/null || true"

  echo ""
  echo "[deploy] Running deploy on $SSH_DEST..."
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && chmod +x scripts/*.sh scripts/sudo/*.sh && ./scripts/deploy.sh"

  post_deploy_checks_remote

  echo ""
  echo "[deploy] Done."
  echo "  Hello-world:  https://$TARGET:8443"
  echo "  n8n:          https://$TARGET:8444"
  echo "  Cockpit:      ./scripts/sudo/deploy-cockpit.sh $TARGET  (separate; https://$TARGET:9443)"
fi
