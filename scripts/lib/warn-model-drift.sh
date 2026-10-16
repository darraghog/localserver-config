# scripts/lib/warn-model-drift.sh (infra repo): advisory model-drift notice for deploy-service.sh.
#
# Source of truth: homelab-arch deploy/infra/warn-model-drift.sh (shipped byte-identical by infra
# patch 0006/04). A sourceable library: it sets no shell options and runs nothing when sourced.
#
#   warn_model_drift <stack>...
#
# Always returns 0 and never aborts a caller running under `set -e`. It only prints notices to
# stderr; it never blocks a deploy (the gates in stack-helpers.sh stay the only blockers).
#   - DEPLOY_SKIP_ARCH_VALIDATE=1: prints nothing.
#   - If $REPO_ROOT/scripts/arch-check.sh is executable, python3 exists and the pinned checker's app
#     repo (HLA_APP_REPO, default $HOME/dev/homelab-arch) is a directory, runs it with output
#     discarded: exit 1 prints the drift notice once; exit 0 or >= 2 (unrunnable, e.g. on the
#     server) prints nothing.
#   - If a stack is homelab-arch and the vendored ontology hash differs from the metamodel's
#     `  ontology_hash:` stamp (same normalisation as arch-check.sh), prints a sync --check reminder.

warn_model_drift() {
  local root="${REPO_ROOT:-}" stack rc=0 vendored="" stamped="" want_reminder=0

  if [[ "${DEPLOY_SKIP_ARCH_VALIDATE:-}" == "1" ]]; then
    return 0
  fi
  [[ -n "$root" ]] || return 0

  local check="$root/scripts/arch-check.sh"
  local app_repo="${HLA_APP_REPO:-${HOME:-}/dev/homelab-arch}"
  if [[ -f "$check" && -x "$check" && -d "$app_repo" ]] && command -v python3 >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
      timeout 120 "$check" </dev/null >/dev/null 2>&1 || rc=$?
    else
      "$check" </dev/null >/dev/null 2>&1 || rc=$?
    fi
    if [[ "$rc" -eq 1 ]]; then
      echo "[arch] NOTICE: provisioning YAML, export or ontology differ from the committed model. Not blocking. See docs/ADD-SERVICE.md section 10." >&2
    fi
  fi

  for stack in "$@"; do
    [[ "$stack" == "homelab-arch" ]] && want_reminder=1
  done
  if [[ "$want_reminder" -eq 1 ]]; then
    local vf="$root/compose/homelab-arch/app/ontology/ontology_v2.hash"
    local mf="$root/architecture/metamodel.yaml"
    if [[ -f "$vf" && -r "$vf" && -f "$mf" && ! -L "$mf" ]]; then
      vendored=$(head -c 200 -- "$vf" 2>/dev/null) || vendored=""
      vendored=${vendored%$'\n'}
      stamped=$(grep -m1 -E '^  ontology_hash: [0-9a-f]{64}$' < <(head -c 1048576 -- "$mf" 2>/dev/null)) || stamped=""
      stamped=${stamped#  ontology_hash: }
      if [[ "$vendored" =~ ^[0-9a-f]{64}$ && "$stamped" =~ ^[0-9a-f]{64}$ && "$vendored" != "$stamped" ]]; then
        echo "[arch] NOTICE: the vendored ontology differs from the one the graph was last exported with. After this deploy run sync --check (docs/change-playbook.md section 2 step 4)." >&2
      fi
    fi
  fi
  return 0
}
