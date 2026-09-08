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

# --- gqldb -------------------------------------------------------------------
# The graph database dumps itself rather than being file-copied, same rule as the SQL
# stores above: BACKUP DATABASE makes the server flush and write its own per-graph archives
# while it keeps serving. It writes a DIRECTORY (one <graph>.gqlbackup.tar.gz each, plus
# db_backup_meta.json and meta.json), not a single file, and creates the target if absent -
# so each run gets its own timestamped subdirectory and is removed once collected.
#
# Two things force the shape of the calls below, both verified against the running server:
#   - gRPC reflection is behind the auth interceptor, so grpcurl needs the vendored
#     gqldb.proto baked into the image; without it not even Login can be resolved.
#   - The session id comes back from Login and travels as a "session-id" metadata header.
# The password reaches grpcurl on stdin as jq-built JSON and never appears in an argv,
# which `ps` would expose to every user on the host.
log "  gqldb (Ultipa GQLDB 6.2.131)"
gq="$(cid gqldb gqldb)"
# All JSON is built and parsed INSIDE the container: it is the one place jq is guaranteed
# to exist (the image installs it), so this does not quietly depend on the host having jq.
# Values cross the boundary as env vars, never interpolated into a shell string.
gq_session="$(podman exec -i "$gq" sh -c '
    jq -nc --arg u "${GQLDB_ADMIN_USER:-admin}" --arg p "$GQLDB_RBAC_ADMIN_PASSWORD" \
       "{username:\$u,password:\$p}" |
    grpcurl -plaintext -import-path /opt/gqldb -proto gqldb.proto -d @ -max-time 15 \
      127.0.0.1:60061 gqldb.SessionService/Login |
    jq -r ".sessionId // empty"')"
[[ -n "$gq_session" ]] || fail "gqldb login failed — cannot take a backup"

gq_gql() {
  podman exec -i -e GQL_STMT="$1" -e GQL_SESSION="$gq_session" "$gq" sh -c '
    jq -nc --arg q "$GQL_STMT" "{gql:\$q}" |
    grpcurl -plaintext -import-path /opt/gqldb -proto gqldb.proto \
      -H "session-id: $GQL_SESSION" -d @ -max-time 300 \
      127.0.0.1:60061 gqldb.QueryService/Gql'
}

gq_run="run-$(date -u +%Y%m%dT%H%M%SZ)"
gq_gql "BACKUP DATABASE TO '/backups/$gq_run'" >/dev/null \
  || fail "gqldb BACKUP DATABASE failed"

# Collect, then verify every archive the server produced. gzip -t plus a tar listing is the
# same truncation check verify_dump applies to the SQL dumps: a half-written archive is a
# valid file and an invalid backup.
podman cp "$gq:/backups/$gq_run" "$STAGE/gqldb" \
  || fail "could not collect gqldb backup $gq_run"
podman exec "$gq" rm -rf "/backups/$gq_run" || true
podman exec -e GQL_SESSION="$gq_session" "$gq" sh -c '
  grpcurl -plaintext -import-path /opt/gqldb -proto gqldb.proto \
    -H "session-id: $GQL_SESSION" -d "{}" -max-time 15 \
    127.0.0.1:60061 gqldb.SessionService/Logout' >/dev/null 2>&1 || true

[[ -f "$STAGE/gqldb/db_backup_meta.json" ]] || fail "gqldb backup has no db_backup_meta.json"
gq_archives=0
for a in "$STAGE"/gqldb/*.gqlbackup.tar.gz; do
  [[ -e "$a" ]] || fail "gqldb backup contains no graph archives"
  gzip -t "$a" 2>/dev/null || fail "$(basename "$a") is not a valid gzip stream"
  # The listing is captured, not piped into grep. Under `set -o pipefail` a `tar | grep -q`
  # fails with 141: grep -q exits at the first match and tar dies on SIGPIPE, so a PERFECTLY
  # GOOD archive reports a backup failure. Observed, not theoretical.
  gq_listing="$(tar -tzf "$a" 2>/dev/null)" || fail "$(basename "$a") is a truncated tar"
  grep -q '^backup_meta.json$' <<<"$gq_listing" \
    || fail "$(basename "$a") has no backup_meta.json — archive is incomplete"
  log "  ok $(basename "$a") ($(stat -c %s "$a") bytes)"
  gq_archives=$((gq_archives + 1))
done
log "  gqldb: $gq_archives graph archive(s) collected"

# The console's own embedded store has no dump command of its own, so it is stopped for a
# cold copy. That honours the same rule as the SQL dumps: what this repo forbids is copying
# a database directory while it is being written, not file copies as such.
#
# podman volume export, not podman cp: the store is a named volume, and exporting the volume
# directly avoids depending on whether `podman cp` traverses into a volume mount on a
# STOPPED container. It also yields a single tar that can be integrity-checked like the
# other archives. The stack is restarted whether or not the export succeeds.
log "  gqldb manager (embedded store, cold copy)"
gq_mgr="$(cid gqldb manager)"
gq_mgr_vol="$(podman inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' "$gq_mgr")"
[[ -n "$gq_mgr_vol" ]] || fail "could not resolve the gqldb manager /data volume"

podman stop -t 60 "$gq_mgr" >/dev/null
gq_mgr_rc=0
podman volume export "$gq_mgr_vol" -o "$STAGE/gqldb-manager.tar" || gq_mgr_rc=$?
podman start "$gq_mgr" >/dev/null
[[ "$gq_mgr_rc" -eq 0 ]] || fail "could not export the gqldb manager store ($gq_mgr_vol)"

# An empty or metadata-only tar here would be the classic healthy-looking zero: the console
# would restore with no saved connections and no users. Assert the store is actually inside.
gq_mgr_listing="$(tar -tf "$STAGE/gqldb-manager.tar" 2>/dev/null)" \
  || fail "gqldb-manager.tar is not a valid tar"
# Captured, not piped — same SIGPIPE-under-pipefail trap as the graph archives above.
grep -q 'manager\.gdb/meta\.json$' <<<"$gq_mgr_listing" \
  || fail "gqldb-manager.tar has no manager.gdb/meta.json — the volume export is empty"
log "  ok gqldb-manager.tar ($(stat -c %s "$STAGE/gqldb-manager.tar") bytes)"

# Provenance: which image versions produced these dumps. Restoring a PG 16 dump into PG 15
# fails, and it is much easier to check here than to discover during an incident.
{
  echo "host:      $(hostname)"
  echo "created:   $(date -Is)"
  echo "images:"
  for spec in "n8n postgres" "litellm db" "wordpress db" "gqldb gqldb" "gqldb manager"; do
    # shellcheck disable=SC2086
    set -- $spec
    printf "  %-12s %s\n" "$1/$2" "$(podman inspect -f '{{.ImageName}}' "$(cid "$1" "$2")")"
  done
  echo "dumps:"
  ( cd "$STAGE" && for f in *.sql.gz; do printf "  %-28s %s bytes\n" "$f" "$(stat -c %s "$f")"; done )
  # The graph stores are directories, not single .sql.gz files, so they need their own pass.
  ( cd "$STAGE" && [ -d gqldb ] && printf "  %-28s %s\n" "gqldb/" "$(du -sh gqldb | cut -f1)"
    cd "$STAGE" && [ -f gqldb-manager.tar ] && \
      printf "  %-28s %s bytes\n" "gqldb-manager.tar" "$(stat -c %s gqldb-manager.tar)" )
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
