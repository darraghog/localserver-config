#!/usr/bin/env bash
# Weekly export freshness check (N5 design D6): does the homelab-arch graph still match the
# committed architecture/export.json? Runs ON the server, from
# localserver-homelab-arch-export-check.service (weekly, via its timer).
#
# A stale graph (someone approved a change and nobody re-exported) or a failed check makes this
# script, and so the unit, fail. scripts/emit-unit-metrics.sh then reports the failed unit and
# the SystemdUserUnitFailed alert fires: no alert wiring of its own is needed.
#
# Before the N5 cutover commits architecture/export.json there is nothing to compare: the script
# says so and exits 0, so the timer can be enabled early without alerting.
#
# Source of truth: homelab-arch deploy/infra/homelab-arch-export-check.sh (held patch 0004).
#
# Usage: scripts/homelab-arch-export-check.sh
# Exit codes: those of `python -m homelab_arch export --check -` (0 fresh, 1 stale, 2 refused,
# 3 graph or ontology error, 4 the graph does not hold this ontology; anything else is podman's,
# e.g. 125 when the container is not running); 0 when no export is committed yet; 2 when
# export.json exists but is not a readable regular file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${HLA_CONTAINER:-homelab-arch_app_1}"
EXPORT="$REPO_ROOT/architecture/export.json"

if [[ ! -e $EXPORT && ! -L $EXPORT ]]; then
    echo "[export-check] no committed export yet ($EXPORT is missing): nothing to check, skipped"
    exit 0
fi
if [[ ! -f $EXPORT || ! -r $EXPORT ]]; then
    echo "[export-check] ERROR: $EXPORT is not a readable regular file" >&2
    exit 2
fi

rc=0
podman exec -i "$CONTAINER" python -m homelab_arch export --check - <"$EXPORT" || rc=$?
case $rc in
0) echo "[export-check] fresh: the graph matches the committed export" ;;
1) echo "[export-check] STALE: the graph differs from the committed export; run scripts/arch-export.sh, review and commit" >&2 ;;
*) echo "[export-check] ERROR: the check could not run (exit $rc)" >&2 ;;
esac
exit "$rc"
