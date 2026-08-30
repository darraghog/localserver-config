#!/usr/bin/env bash
# Off-box backup: dump every Podman-managed database, then push dumps + non-database state
# + secrets to Azure Blob via restic. Run weekly by localserver-backup.timer.
#
# Usage: ./scripts/backup.sh
#
# Restore procedure: docs/BACKUP.md. A backup that has never been restored is not a backup.
#
# WHY LOGICAL DUMPS, NOT VOLUME COPIES: the database volumes (postgres-data,
# litellm_litellm-postgres, wordpress_wordpress-db) are deliberately NOT backed up as files.
# Copying a live database's data directory without a filesystem snapshot yields a torn image
# that frequently will not restore. pg_dump / mariadb-dump are the only supported path, and
# scripts/restic.sh mounts only the non-database volumes for exactly this reason.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log() { echo "[backup] $*"; }
fail() { echo "[backup] ERROR: $*" >&2; exit 1; }

[[ -f "$REPO_ROOT/.env" ]] || fail "no .env at $REPO_ROOT/.env"
set -a; source "$REPO_ROOT/.env"; set +a

# Resolve containers by compose label, not by the "_1" suffix, which podman-compose changes
# between versions (same approach as scripts/wp-cli.sh).
cid() {
  local project="$1" service="$2" id
  id="$(podman ps -q --filter "label=io.podman.compose.project=$project" \
                     --filter "label=io.podman.compose.service=$service" | head -1)"
  [[ -n "$id" ]] || fail "container not running: project=$project service=$service"
  printf '%s' "$id"
}

STAGE="$(mktemp -d "$HOME/.backup-stage.XXXXXX")"
chmod 700 "$STAGE"
# The staging dir holds plaintext database dumps; never leave it lying around.
trap 'rm -rf "$STAGE"' EXIT INT TERM

# A dump that fails midway can still leave a valid gzip stream, so check the decompressed
# dump ends the way the tool actually ends a complete dump. Silent truncation is the classic
# way a backup scheme looks healthy for months and then cannot restore.
#
# The 20-line window is deliberate. PostgreSQL 15/16 writes "-- PostgreSQL database dump
# complete" as the 5th-from-last line, followed by a blank line and a "\unrestrict <token>"
# trailer that recent releases added. A tighter tail would sit exactly on that boundary and
# start failing every backup the moment a minor release adds one more trailing line.
verify_dump() {
  local f="$1" marker="$2" size
  [[ -s "$f" ]] || fail "$(basename "$f") is empty"
  size="$(stat -c %s "$f")"
  gzip -t "$f" 2>/dev/null || fail "$(basename "$f") is not a valid gzip stream"
  zcat "$f" | tail -20 | grep -qF "$marker" \
    || fail "$(basename "$f") is truncated (no '$marker' terminator) — dump did not complete"
  log "  ok $(basename "$f") ($size bytes)"
}

log "Dumping databases..."

log "  n8n (postgres 15)"
podman exec -e PGPASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set in .env}" \
  "$(cid n8n postgres)" pg_dump -U n8n -d n8n --clean --if-exists \
  | gzip > "$STAGE/n8n-postgres.sql.gz"
verify_dump "$STAGE/n8n-postgres.sql.gz" "PostgreSQL database dump complete"

log "  litellm (postgres 16)"
podman exec -e PGPASSWORD="${POSTGRES_PASSWORD}" \
  "$(cid litellm db)" pg_dump -U litellm -d litellm --clean --if-exists \
  | gzip > "$STAGE/litellm-postgres.sql.gz"
verify_dump "$STAGE/litellm-postgres.sql.gz" "PostgreSQL database dump complete"

# --single-transaction takes the dump inside one consistent InnoDB snapshot WITHOUT locking
# the tables, so the blog keeps serving throughout. Dumping as root (not the wordpress user)
# so --routines/--triggers can't fail on a privilege check.
log "  wordpress (mariadb 11.8)"
podman exec -e MYSQL_PWD="${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD not set in .env}" \
  "$(cid wordpress db)" mariadb-dump -u root \
    --single-transaction --routines --triggers --databases wordpress \
  | gzip > "$STAGE/wordpress-mariadb.sql.gz"
verify_dump "$STAGE/wordpress-mariadb.sql.gz" "Dump completed"

# Provenance: which image versions produced these dumps. Restoring a PG 16 dump into PG 15
# fails, and it is much easier to check here than to discover during an incident.
{
  echo "host:      $(hostname)"
  echo "created:   $(date -Is)"
  echo "images:"
  for spec in "n8n postgres" "litellm db" "wordpress db"; do
    # shellcheck disable=SC2086
    set -- $spec
    printf "  %-12s %s\n" "$1/$2" "$(podman inspect -f '{{.ImageName}}' "$(cid "$1" "$2")")"
  done
  echo "dumps:"
  ( cd "$STAGE" && for f in *.sql.gz; do printf "  %-28s %s bytes\n" "$f" "$(stat -c %s "$f")"; done )
} > "$STAGE/manifest.txt"
cat "$STAGE/manifest.txt"

log "Uploading to Azure Blob via restic..."
export BACKUP_STAGE="$STAGE"

# Cool tier: this data is written once and read almost never. The 30-day early-deletion
# charge never applies under a 12-week retention.
"$REPO_ROOT/scripts/restic.sh" backup \
  /backup/dumps /backup/volumes /backup/config \
  --tag weekly --tag beeblebox \
  --host beeblebox \
  -o azure.access-tier=Cool

log "Applying retention (keep 12 weekly)..."
"$REPO_ROOT/scripts/restic.sh" forget --keep-weekly 12 --prune --host beeblebox

log "Checking repository integrity..."
"$REPO_ROOT/scripts/restic.sh" check

log "Done."
