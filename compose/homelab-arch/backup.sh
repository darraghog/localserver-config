#!/usr/bin/env bash
# Consistent backup of the homelab-arch proposal queue and audit log (SQLite on the
# homelab-arch_proposals-data volume). Runs ON the server; called by scripts/backup.sh.
# A file copy of the live database would not be a backup, and the volume belongs to a
# sub-uid, so the app writes an online, integrity-checked copy inside the container and
# podman cp brings it out.
#
# Usage: compose/homelab-arch/backup.sh <dest-dir>   -> <dest-dir>/homelab-arch-proposals.db
set -euo pipefail
# The copy holds raw proposal values and the audit log: never group- or world-readable.
umask 077

DEST="${1:?usage: backup.sh <dest-dir>}"
CONTAINER="${HLA_CONTAINER:-homelab-arch_app_1}"
OUT="$DEST/homelab-arch-proposals.db"

mkdir -p "$DEST"
# Best effort, on every exit: leave no second full copy in the volume or a half-copied .tmp.
# Failures of the backup itself stay loud (set -e); only the cleanup is allowed to fail.
cleanup() {
  podman exec "$CONTAINER" rm -f /data/backup/proposals.db >/dev/null 2>&1 || true
  rm -f "$OUT.tmp"
}
trap cleanup EXIT
# A stale copy from an earlier failed run must not be mistaken for this run's output.
podman exec "$CONTAINER" rm -f /data/backup/proposals.db
podman exec "$CONTAINER" python -m homelab_arch backup-proposals /data/backup/proposals.db
podman cp "$CONTAINER:/data/backup/proposals.db" "$OUT.tmp"
# Do not leave a second full copy inside the volume.
podman exec "$CONTAINER" rm -f /data/backup/proposals.db
python3 - "$OUT.tmp" <<'PY'
import sqlite3
import sys

con = sqlite3.connect(sys.argv[1])
verdict = con.execute("PRAGMA integrity_check").fetchone()[0]
con.close()
sys.exit(0 if verdict == "ok" else f"integrity check failed: {verdict}")
PY
mv "$OUT.tmp" "$OUT"
echo "[backup homelab-arch] $OUT"
