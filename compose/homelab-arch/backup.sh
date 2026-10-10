#!/usr/bin/env bash
# Consistent backup of the homelab-arch proposal queue and audit log (SQLite on the
# homelab-arch_proposals-data volume). Runs ON the server; called by scripts/backup.sh.
# A file copy of the live database would not be a backup, and the volume belongs to a
# sub-uid, so the app writes an online, integrity-checked copy inside the container and
# podman cp brings it out.
#
# Usage: compose/homelab-arch/backup.sh <dest-dir>   -> <dest-dir>/homelab-arch-proposals.db
#                                                     (+ <dest-dir>/homelab-arch-sync-runs.jsonl)
# sync-runs.jsonl, the append-only log of provisioning-sync and bootstrap runs, lives next to
# proposals.db (not in it, so the store schema never changes for it). It exists only after the
# first such run; until then it is skipped quietly.
set -euo pipefail
# The copy holds raw proposal values and the audit log: never group- or world-readable.
umask 077

DEST="${1:?usage: backup.sh <dest-dir>}"
CONTAINER="${HLA_CONTAINER:-homelab-arch_app_1}"
OUT="$DEST/homelab-arch-proposals.db"
RUNS="$DEST/homelab-arch-sync-runs.jsonl"

mkdir -p "$DEST"
# Best effort, on every exit: leave no second full copy in the volume or a half-copied .tmp.
# Failures of the backup itself stay loud (set -e); only the cleanup is allowed to fail.
cleanup() {
  podman exec "$CONTAINER" rm -f /data/backup/proposals.db >/dev/null 2>&1 || true
  rm -f "$OUT.tmp" "$RUNS.tmp"
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

# The run log is append-only, so podman cp of the live file is a consistent copy up to its
# last complete line. Every line must parse as JSON; a torn final line (a run writing right
# now) is dropped rather than failing the backup. Missing file: nothing to back up yet.
if podman exec "$CONTAINER" test -f /data/sync-runs.jsonl; then
  podman cp "$CONTAINER:/data/sync-runs.jsonl" "$RUNS.tmp"
  python3 - "$RUNS.tmp" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "rb") as f:
    data = f.read()
if data and not data.endswith(b"\n"):
    data = data[: data.rfind(b"\n") + 1]  # drop a torn final line
for n, line in enumerate(data.splitlines(), 1):
    try:
        json.loads(line)
    except ValueError:
        sys.exit(f"sync-runs.jsonl: line {n} is not JSON")
with open(path, "wb") as f:
    f.write(data)
PY
  mv "$RUNS.tmp" "$RUNS"
  echo "[backup homelab-arch] $RUNS"
else
  rm -f "$RUNS"  # never leave an older run's copy looking like this run's
  echo "[backup homelab-arch] no sync-runs.jsonl yet (written by the first provisioning run); skipped"
fi
