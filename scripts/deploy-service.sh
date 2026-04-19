#!/usr/bin/env bash
# Deploy one or more compose stacks independently to a target (sync repo, env file, deploy-stack).
# Assumes Podman and podman-compose are already installed on the target (see scripts/sudo/bootstrap-host.sh).
#
# Usage:
#   ./scripts/deploy-service.sh [options] <env> <target> <stack> [<stack> ...]
#
# Options:
#   --ssh-port PORT     SSH/rsync/scp port (default: 22 or DEPLOY_SSH_PORT)
#   --remote-path PATH  Remote repo directory (default: ~/localserver-config)
#   --no-sync           Skip rsync; only copy env and run deploy-stack (remote only)
#   --verify            After deploy, run the same port/TLS checks as deploy-to-server.sh (prod only)
#
# env:    selects envs/<env>.env → copied to .env on the target
# target: 'local', hostname, or user@host (same local detection as deploy-to-server.sh)
#
# Examples:
#   ./scripts/deploy-service.sh dev local tic-tac-toe
#   ./scripts/deploy-service.sh prod darragh-pc tic-tac-toe
#   ./scripts/deploy-service.sh --ssh-port 2222 prod user@darragh-pc tic-tac-toe tls-proxy
#   DEPLOY_SSH_DEST=user@192.168.1.50 ./scripts/deploy-service.sh prod darragh-pc hello-world
#
# Environment variables (optional):
#   DEPLOY_SSH_DEST, DEPLOY_SSH_PORT  — same as deploy-to-server.sh
#   DEPLOY_REMOTE_PATH                — default for --remote-path (default ~/localserver-config)
#   DEPLOY_CERT_EXTRA_SANS, CHECK_TLS_CURL_HOST — used with --verify on prod (see check-tls.sh)
#
# deploy-stack.sh runs compose/<stack>/build.sh (tests + image) first, then start-stack, then
# caddy reload on tls-proxy after app stacks (Caddyfile changes) and
# curls each stack via its Caddy HTTPS port when certs exist. You can still add tls-proxy to the
# stack list to recreate the proxy container in the same run.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SSH_PORT="${DEPLOY_SSH_PORT:-}"
REMOTE_PATH="${DEPLOY_REMOTE_PATH:-~/localserver-config}"
SYNC=1
VERIFY=0

usage() {
  echo "Usage: $(basename "$0") [options] <env> <target> <stack> [<stack> ...]" >&2
  echo "  Options: --ssh-port PORT  --remote-path PATH  --no-sync  --verify" >&2
  echo "  env:     name of envs/<env>.env" >&2
  echo "  target: local | hostname | user@host" >&2
  echo "  stack:  compose directory name(s), e.g. tic-tac-toe n8n tls-proxy" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-port)
      SSH_PORT="${2:?}"
      shift 2
      ;;
    --remote-path)
      REMOTE_PATH="${2:?}"
      shift 2
      ;;
    --no-sync)
      SYNC=0
      shift
      ;;
    --verify)
      VERIFY=1
      shift
      ;;
    -h | --help)
      usage
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -ge 3 ]] || usage

ENV_NAME="${1:?}"
TARGET="${2:?}"
shift 2
STACKS=("$@")
[[ ${#STACKS[@]} -ge 1 ]] || usage

SSH_PORT="${SSH_PORT:-22}"
SSH_DEST="${DEPLOY_SSH_DEST:-$TARGET}"

SSH_PORT_ARGS=()
SCP_PORT_ARGS=()
RSYNC_SSH=()
if [[ -n "$SSH_PORT" && "$SSH_PORT" != "22" ]]; then
  SSH_PORT_ARGS=(-p "$SSH_PORT")
  SCP_PORT_ARGS=(-P "$SSH_PORT")
  RSYNC_SSH=(-e "ssh -p $SSH_PORT")
fi

ENV_FILE="$REPO_ROOT/envs/$ENV_NAME.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: env file not found: $ENV_FILE" >&2
  echo "Create it from: cp .env.example envs/$ENV_NAME.env" >&2
  exit 1
fi

# shellcheck source=scripts/lib/deploy-target.sh
source "$REPO_ROOT/scripts/lib/deploy-target.sh"

ssh_port_hint() {
  echo "[deploy-service] If connection failed, sshd may not be on port ${SSH_PORT}." >&2
  echo "  Try: $(basename "$0") --ssh-port 22 $ENV_NAME $TARGET ${STACKS[*]}" >&2
}

# shellcheck source=scripts/lib/stack-helpers.sh
source "$REPO_ROOT/scripts/lib/stack-helpers.sh"

for s in "${STACKS[@]}"; do
  assert_stack_compose_exists "$s" || exit 1
done

run_deploy_stacks() {
  "$REPO_ROOT/scripts/deploy-stack.sh" "${STACKS[@]}"
}

post_deploy_checks_local() {
  [[ "$VERIFY" -eq 1 ]] || return 0
  echo ""
  echo "[deploy-service] Running port checks (--verify)..."
  "$REPO_ROOT/tests/check-ports.sh" --core-only

  if [[ "$ENV_NAME" != "prod" ]]; then
    echo "[deploy-service] Skip TLS/Caddy checks (not prod)."
    return 0
  fi
  if [[ ! -f "$REPO_ROOT/certs/server.pem" ]]; then
    echo "[deploy-service] Skip TLS/Caddy checks (prod but no certs/server.pem)."
    return 0
  fi

  echo ""
  "$REPO_ROOT/tests/check-ports.sh"
  echo ""
  "$REPO_ROOT/scripts/check-tls.sh"
}

post_deploy_checks_remote() {
  [[ "$VERIFY" -eq 1 ]] || return 0
  echo ""
  echo "[deploy-service] Running application port checks on $SSH_DEST (--verify)..."
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && ./tests/check-ports.sh --core-only"

  if [[ "$ENV_NAME" != "prod" ]]; then
    echo "[deploy-service] Skip TLS/Caddy checks (not prod)."
    return 0
  fi
  if ! ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && test -f certs/server.pem"; then
    echo "[deploy-service] Skip TLS/Caddy checks (prod but remote has no certs/server.pem)."
    return 0
  fi

  echo ""
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" "cd $REMOTE_PATH && ./tests/check-ports.sh"
  echo ""
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
    "$REPO_ROOT/scripts/check-tls.sh" "$TARGET" "$curl_tls_host"
  else
    "$REPO_ROOT/scripts/check-tls.sh" "$TARGET"
  fi
}

if deploy_target_is_this_host; then
  echo "[deploy-service] Environment: $ENV_NAME, target: $TARGET (local)"
  echo "[deploy-service] Stacks: ${STACKS[*]}"
  echo ""

  cp "$ENV_FILE" "$REPO_ROOT/.env"
  run_deploy_stacks
  post_deploy_checks_local
else
  echo "[deploy-service] Environment: $ENV_NAME, target: $TARGET"
  echo "[deploy-service] Remote path: $REMOTE_PATH"
  echo "[deploy-service] Stacks: ${STACKS[*]}"
  [[ -n "$SSH_PORT" && "$SSH_PORT" != "22" ]] && echo "[deploy-service] SSH port: $SSH_PORT"
  [[ "$SSH_DEST" != "$TARGET" ]] && echo "[deploy-service] SSH connect as: $SSH_DEST"
  echo ""

  if [[ "$SYNC" -eq 1 ]]; then
    echo "[deploy-service] Syncing repo (preserving remote certs/, excluding envs/)..."
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
  else
    echo "[deploy-service] Skipping rsync (--no-sync)."
  fi

  echo ""
  echo "[deploy-service] Copying env file..."
  scp "${SCP_PORT_ARGS[@]}" "$ENV_FILE" "$SSH_DEST:$REMOTE_PATH/.env"

  echo ""
  echo "[deploy-service] Running deploy-stack on $SSH_DEST..."
  stacks_q="$(printf '%q ' "${STACKS[@]}")"
  # shellcheck disable=SC2029
  ssh "${SSH_PORT_ARGS[@]}" "$SSH_DEST" \
    "cd $REMOTE_PATH && chmod +x scripts/*.sh scripts/sudo/*.sh 2>/dev/null || true && ./scripts/deploy-stack.sh $stacks_q"

  post_deploy_checks_remote
fi

echo ""
echo "[deploy-service] Done."
