#!/usr/bin/env bash
# Run restic against the off-box backup repository (Azure Blob).
# Usage: ./scripts/restic.sh <restic subcommand...>
#   ./scripts/restic.sh init
#   ./scripts/restic.sh snapshots
#   ./scripts/restic.sh check
#   ./scripts/restic.sh restore latest --target /work/restore-test
#
# restic runs as a pinned container rather than an apt install: sudo on this host needs an
# interactive password, and a container matches the repo's rootless-podman model.
#
# Credentials live OUTSIDE the repo in ~/.config/localserver/backup.env (chmod 600) because
# they include RESTIC_PASSWORD, which decrypts everything. See docs/BACKUP.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESTIC_IMAGE="${RESTIC_IMAGE:-docker.io/restic/restic:0.19.1}"
CREDS="${BACKUP_ENV_FILE:-$HOME/.config/localserver/backup.env}"

[[ -f "$CREDS" ]] || {
  cat >&2 <<EOF
ERROR: no backup credentials at $CREDS

Create it (chmod 600, never in the repo) with:
  AZURE_ACCOUNT_NAME=<storage account>
  AZURE_ACCOUNT_KEY=<account key or use AZURE_ACCOUNT_SAS>
  RESTIC_REPOSITORY=azure:beeblebox-backups:/
  RESTIC_PASSWORD=<long random passphrase, also stored in your password manager>

See docs/BACKUP.md.
EOF
  exit 1
}

# Refuse to run if the credentials file is group/world readable — it holds the key that
# decrypts every backup, including .env.
perms="$(stat -c '%a' "$CREDS")"
if [[ "$perms" != "600" && "$perms" != "400" ]]; then
  echo "ERROR: $CREDS has mode $perms; expected 600. Run: chmod 600 $CREDS" >&2
  exit 1
fi

# Writable scratch space for restores. Never inside the repo.
WORK="${RESTIC_WORK_DIR:-$HOME/restic-work}"
mkdir -p "$WORK"

mounts=(-v "$WORK:/work")

# Non-database state, read-only. Paths come from podman rather than being hardcoded, since
# rootless volume paths are an implementation detail of the storage driver.
for v in wordpress_wordpress-data n8n_n8n-data weather-mcp_oauth-store; do
  mp="$(podman volume inspect "$v" --format '{{.Mountpoint}}' 2>/dev/null || true)"
  if [[ -n "$mp" && -d "$mp" ]]; then
    mounts+=(-v "$mp:/backup/volumes/${v}:ro")
  else
    echo "[restic] WARN: volume $v not found; it will be missing from this snapshot" >&2
  fi
done

# Secrets and host identity. .env is the critical one: without N8N_ENCRYPTION_KEY every
# credential in the n8n dump is undecryptable forever.
[[ -f "$REPO_ROOT/.env" ]]     && mounts+=(-v "$REPO_ROOT/.env:/backup/config/env:ro")
[[ -d "$HOME/.cloudflared" ]]  && mounts+=(-v "$HOME/.cloudflared:/backup/config/cloudflared:ro")
[[ -d "$REPO_ROOT/certs" ]]    && mounts+=(-v "$REPO_ROOT/certs:/backup/config/certs:ro")

# Database dumps, staged by backup.sh for the duration of one run.
if [[ -n "${BACKUP_STAGE:-}" ]]; then
  [[ -d "$BACKUP_STAGE" ]] || { echo "ERROR: BACKUP_STAGE=$BACKUP_STAGE is not a directory" >&2; exit 1; }
  mounts+=(-v "$BACKUP_STAGE:/backup/dumps:ro")
fi

exec podman run --rm -i \
  --env-file "$CREDS" \
  --hostname beeblebox \
  "${mounts[@]}" \
  "$RESTIC_IMAGE" "$@"
