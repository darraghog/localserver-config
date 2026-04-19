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

assert_stack_compose_exists() {
  local name="$1" dir compose
  dir="$REPO_ROOT/compose/$name"
  [[ -d "$dir" ]] || {
    echo "ERROR: No compose/$name directory." >&2
    return 1
  }
  compose="$dir/compose.yaml"
  [[ -f "$compose" ]] || compose="$dir/docker-compose.yaml"
  [[ -f "$compose" ]] || {
    echo "ERROR: No compose.yaml in compose/$name" >&2
    return 1
  }
  return 0
}
