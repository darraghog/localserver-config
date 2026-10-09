#!/usr/bin/env bash
# scripts/arch-export.sh (infra repo): refresh architecture/ from the running app's export.
#
# Source of truth: homelab-arch deploy/infra/arch-export.sh (companion: arch_unbundle.py, installed
# as scripts/lib/arch_unbundle.py). Fetches `export --bundle` over ssh, validates the WHOLE bundle
# with a stdlib-only unbundler (run with -I), writes exactly the four architecture/ files, runs
# scripts/arch-check.sh and shows `git diff --stat`. NOTHING is committed.
#
# Environment:
#   HLA_SSH_HOST   ssh host (default beeblebox); must match ^[A-Za-z0-9._-]+$ and not start with -
#   HLA_CONTAINER  container name (default homelab-arch_app_1); same rule
#   HLA_EXPORT_BUNDLE_FILE  TESTS ONLY: use this bundle file instead of ssh (warns).
# The ssh command line is a fixed constant apart from those two validated words; no -t, so
# stdout stays binary-clean.
#
# Exit: 0 files written (checker findings are reported, not fatal); non-zero when refused.
set -euo pipefail
umask 077

die() { printf 'arch-export: %s\n' "$*" >&2; exit 2; }

HOST=${HLA_SSH_HOST-beeblebox}
C=${HLA_CONTAINER-homelab-arch_app_1}
re='^[A-Za-z0-9._-]+$'
[[ $HOST =~ $re && $HOST != -* ]] || die "HLA_SSH_HOST must match ^[A-Za-z0-9._-]+\$ and not start with '-'"
[[ $C =~ $re && $C != -* ]] || die "HLA_CONTAINER must match ^[A-Za-z0-9._-]+\$ and not start with '-'"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || die "cannot locate the script"
ROOT=$(dirname -- "$script_dir")
MAX=$((8 * 1024 * 1024))

tmp=$(mktemp -d) || die "cannot create a temp dir"
trap 'rm -rf -- "$tmp"' EXIT

if [[ -n ${HLA_EXPORT_BUNDLE_FILE:-} ]]; then
  printf 'arch-export: WARNING: using HLA_EXPORT_BUNDLE_FILE (tests only); ssh is NOT contacted\n' >&2
  cp -- "$HLA_EXPORT_BUNDLE_FILE" "$tmp/b.json" || die "cannot copy HLA_EXPORT_BUNDLE_FILE"
else
  # head caps what a misbehaving remote can put on disk; the unbundler then refuses oversize.
  # pipefail is off so PIPESTATUS (read in this shell) tells ssh's status from head's.
  set +o pipefail
  ssh -n -- "$HOST" podman exec "$C" python -m homelab_arch export --bundle </dev/null \
    | head -c $((MAX + 1)) >"$tmp/b.json"
  st=("${PIPESTATUS[@]}")
  set -o pipefail
  size=$(wc -c <"$tmp/b.json")
  [[ $size -gt 0 ]] || die "ssh/export produced no output (exit ${st[0]})"
  if [[ ${st[0]} -ne 0 && $size -le $MAX ]]; then die "ssh/export failed (exit ${st[0]})"; fi
fi

python3 -I "$ROOT/scripts/lib/arch_unbundle.py" "$tmp/b.json" "$ROOT/architecture" || exit 2
"$ROOT/scripts/arch-check.sh" || echo "arch-export: checks report findings (see above)"
git -C "$ROOT" diff --stat -- architecture/ || true
echo "Review: git diff architecture/  then commit yourself. Nothing was committed."
