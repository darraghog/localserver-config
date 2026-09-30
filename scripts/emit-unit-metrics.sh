#!/usr/bin/env bash
# Export failed systemd USER units as Prometheus textfile metrics for node-exporter.
#
# node-exporter's own systemd collector talks to the system bus, so it cannot see user units,
# which is where every localserver-* unit (backup, stacks, cloudflared) lives. A oneshot unit
# that fails there just sits in "failed" until someone looks: the weekly backup did exactly
# that for three weeks. This bridges the gap.
#
# Run every minute by localserver-unit-metrics.timer. Writes atomically, so node-exporter
# never reads a half-written file. If systemctl cannot reach the user bus the script fails
# and leaves the old file, which the SystemdUnitMetricsStale alert then notices: a broken
# check must not look like "nothing is failing".
#
# Usage: scripts/emit-unit-metrics.sh [output-dir]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/compose/prometheus/textfile}"
OUT="$OUT_DIR/systemd_user_units.prom"

mkdir -p "$OUT_DIR"
# Not *.prom until the mv, so the collector ignores it while it is being written.
tmp="$(mktemp "$OUT_DIR/.systemd_user_units.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

failed="$(systemctl --user list-units --state=failed --plain --no-legend --no-pager | awk 'NF { print $1 }')"

{
  echo '# HELP localserver_systemd_user_unit_failed 1 for each systemd user unit in the failed state.'
  echo '# TYPE localserver_systemd_user_unit_failed gauge'
  count=0
  while IFS= read -r unit; do
    [[ -n "$unit" ]] || continue
    count=$((count + 1))
    # Unit names can contain backslash escapes (e.g. \x2d); escape for the exposition format.
    esc="${unit//\\/\\\\}"; esc="${esc//\"/\\\"}"
    printf 'localserver_systemd_user_unit_failed{unit="%s"} 1\n' "$esc"
  done <<<"$failed"
  echo '# HELP localserver_systemd_user_units_failed Number of systemd user units in the failed state.'
  echo '# TYPE localserver_systemd_user_units_failed gauge'
  echo "localserver_systemd_user_units_failed $count"
} > "$tmp"

chmod 644 "$tmp"   # node-exporter runs as nobody inside the container
mv "$tmp" "$OUT"
