# Shared helpers for stack deploy. Source after REPO_ROOT is set.
# shellcheck shell=bash

list_stack_order() {
  local f="$REPO_ROOT/compose/stack-order"
  [[ -f "$f" ]] || {
    echo "ERROR: Missing $f" >&2
    return 1
  }
  grep -v '^[[:space:]]*#' "$f" | sed 's/#.*//' | awk 'NF && !seen[$1]++ { print $1 }'
}

validate_n8n_env_for_stacks() {
  local need=0 s
  for s in "$@"; do
    [[ "$s" == "n8n" ]] && need=1
  done
  [[ "$need" -eq 0 ]] && return 0

  [[ -z "${N8N_BASIC_AUTH_PASSWORD:-}" ]] && {
    echo "ERROR: N8N_BASIC_AUTH_PASSWORD is not set (required to deploy n8n)." >&2
    return 1
  }
  [[ -z "${N8N_ENCRYPTION_KEY:-}" ]] && {
    echo "ERROR: N8N_ENCRYPTION_KEY is not set (required to deploy n8n)." >&2
    return 1
  }
  return 0
}

# WordPress's MariaDB exits on startup when its passwords are unset, and restart:unless-stopped
# then retries forever — a silent crash loop rather than a failed deploy. Fail here instead.
validate_wordpress_env_for_stacks() {
  local need=0 s
  for s in "$@"; do
    [[ "$s" == "wordpress" ]] && need=1
  done
  [[ "$need" -eq 0 ]] && return 0

  [[ -z "${WORDPRESS_DB_PASSWORD:-}" ]] && {
    echo "ERROR: WORDPRESS_DB_PASSWORD is not set (required to deploy wordpress)." >&2
    echo "       Set it in .env — without it MariaDB refuses to initialise and the db" >&2
    echo "       container restarts indefinitely instead of failing." >&2
    return 1
  }
  [[ -z "${MARIADB_ROOT_PASSWORD:-}" ]] && {
    echo "ERROR: MARIADB_ROOT_PASSWORD is not set (required to deploy wordpress)." >&2
    echo "       Set it in .env — see .env.example." >&2
    return 1
  }
  return 0
}

assert_stack_compose_exists() {
  local name="$1" dir compose
  dir="$REPO_ROOT/compose/$name"
  [[ -d "$dir" ]] || {
    echo "ERROR: No compose/$name directory." >&2
    return 1
  }
  compose="$dir/compose.yaml"
  [[ -f "$compose" ]] || {
    echo "ERROR: No compose.yaml in compose/$name" >&2
    return 1
  }
  return 0
}

# Refuse to deploy an estate whose architecture model no longer describes it.
#
# architecture/model.yaml is the single source of truth for which services exist, how they are
# routed, and which dependent project owns each locally-built component (see docs/ADD-SERVICE.md).
# That only holds while something enforces it — a model nobody checks drifts exactly as fast as
# the prose it replaced. scripts/arch-validate.py is stdlib-only, so this runs on the server too.
#
# Break-glass: DEPLOY_SKIP_ARCH_VALIDATE=1 (announced loudly; use it to ship a fix, not to live in).
require_conformant_model() {
  local root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  local validator="$root/scripts/arch-validate.py"
  local model="$root/architecture/model.yaml"

  if [[ "${DEPLOY_SKIP_ARCH_VALIDATE:-}" == "1" ]]; then
    echo "[arch] WARNING: model validation skipped (DEPLOY_SKIP_ARCH_VALIDATE=1)." >&2
    echo "[arch] Deploying without checking that the architecture model matches the estate." >&2
    return 0
  fi

  if [[ ! -f "$model" || ! -f "$validator" ]]; then
    echo "[arch] ERROR: architecture model or validator missing." >&2
    echo "[arch]   expected: $model" >&2
    echo "[arch]             $validator" >&2
    echo "[arch] An estate with no checked description is what this gate exists to prevent." >&2
    return 1
  fi

  if ! command -v python3 &>/dev/null; then
    echo "[arch] ERROR: python3 not found; cannot validate the architecture model." >&2
    echo "[arch] arch-validate.py needs no third-party packages — install python3." >&2
    return 1
  fi

  echo "[arch] Validating architecture model..."
  if ! python3 "$validator"; then
    echo "" >&2
    echo "[arch] ERROR: architecture/model.yaml does not conform — refusing to deploy." >&2
    echo "[arch] Update the model to match what you are deploying, then retry." >&2
    echo "[arch] (Adding a service? docs/ADD-SERVICE.md step 10.)" >&2
    return 1
  fi
}
