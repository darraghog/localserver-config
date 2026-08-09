# shellcheck shell=bash
# Post-deploy: caddy reload on tls-proxy (no container restart), then curl HTTPS on each
# deployed stack's Caddy front door. Source after REPO_ROOT is set.

reload_tls_proxy_if_possible() {
  if [[ "${DEPLOY_SKIP_TLS_PROXY_RELOAD:-}" == "1" || "${DEPLOY_SKIP_TLS_PROXY_RESTART:-}" == "1" ]]; then
    echo "[post-deploy-caddy] Skip Caddy reload (DEPLOY_SKIP_TLS_PROXY_RELOAD or DEPLOY_SKIP_TLS_PROXY_RESTART=1)"
    return 0
  fi
  [[ -f "$REPO_ROOT/certs/server.pem" ]] || {
    echo "[post-deploy-caddy] Skip Caddy reload: no certs/server.pem"
    return 0
  }
  [[ -d "$REPO_ROOT/compose/tls-proxy" ]] || return 0

  local last_s=""
  for _s in "$@"; do last_s="$_s"; done
  if [[ "$last_s" == "tls-proxy" ]]; then
    echo "[post-deploy-caddy] Skipping extra Caddy reload (last deployed stack was tls-proxy; already reloaded after up)."
    return 0
  fi

  echo "[post-deploy-caddy] Reloading Caddy (caddy reload) so new Caddyfile sites are active..."
  "$REPO_ROOT/scripts/reload-tls-proxy-caddy.sh" || {
    echo "[post-deploy-caddy] WARN: caddy reload failed; try: ./scripts/start-stack.sh tls-proxy restart" >&2
    return 0
  }
}

# First host-published port from compose/<stack>/compose.yaml (first "ports:" list entry).
compose_first_published_host_port() {
  local stack="$1"
  local f="$REPO_ROOT/compose/$stack/compose.yaml"
  [[ -f "$f" ]] || return 1
  awk '
    /^[[:space:]]*ports:[[:space:]]*$/ { p = 1; next }
    p && /^[[:space:]]*[^#[:space:]-]/ && !/^[[:space:]]*- / { exit }
    p && /^[[:space:]]*- "/ {
      line = $0
      sub(/^[[:space:]]*- "/, "", line)
      sub(/".*$/, "", line)
      n = split(line, a, ":")
      if (n == 2) { print a[1] + 0; exit }
      if (n > 2) { print a[n - 1] + 0; exit }
    }
  ' "$f"
}

# Map backend host port -> Caddy HTTPS listen port using Caddyfile.
caddy_https_port_for_backend() {
  local backend="$1"
  local caddyfile="$REPO_ROOT/compose/tls-proxy/Caddyfile"
  [[ -f "$caddyfile" ]] || return 1
  local out
  out="$(awk -f "$REPO_ROOT/scripts/lib/caddy-site-ports.awk" "$caddyfile" | awk -v be="$backend" '$2 == be { print $1; exit }')"
  [[ -n "$out" ]] || return 1
  printf '%s' "$out"
}

# HTTPS path to curl on the Caddy front door (stack-specific).
caddy_verify_path_for_stack() {
  case "$1" in
    litellm) printf '%s' "/health/liveliness" ;;
    n8n) printf '%s' "/healthz" ;;
    *) printf '%s' "/" ;;
  esac
}

# Poll the app backend before hitting Caddy (avoids 502 while containers warm up).
wait_for_stack_backend() {
  local stack="$1" be="$2"
  local max_tries=5 sleep_sec=2
  case "$stack" in
    litellm) max_tries=45 sleep_sec=2 ;; # Postgres + DB migrate; compose start_period=90s
    n8n) max_tries=15 sleep_sec=2 ;;
  esac

  local path try code
  path="$(caddy_verify_path_for_stack "$stack")"
  echo "[post-deploy-caddy] Waiting for $stack backend http://127.0.0.1:${be}${path} ..."
  for try in $(seq 1 "$max_tries"); do
    code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 8 "http://127.0.0.1:${be}${path}" 2>/dev/null || true)"
    if [[ "$code" =~ ^[23] ]]; then
      echo "[post-deploy-caddy] Backend ready ($stack HTTP $code)"
      return 0
    fi
    [[ "$try" -lt "$max_tries" ]] && sleep "$sleep_sec"
  done
  echo "[post-deploy-caddy] WARN: $stack backend not ready after $((max_tries * sleep_sec))s (last HTTP ${code:-000})" >&2
  return 1
}

verify_deployed_stacks_via_caddy() {
  [[ "${DEPLOY_SKIP_CADDY_VERIFY:-}" == "1" ]] && {
    echo "[post-deploy-caddy] Skip Caddy HTTPS verify (DEPLOY_SKIP_CADDY_VERIFY=1)"
    return 0
  }
  [[ -f "$REPO_ROOT/certs/server.pem" ]] || {
    echo "[post-deploy-caddy] Skip Caddy HTTPS verify: no certs/server.pem"
    return 0
  }
  command -v curl &>/dev/null || {
    echo "[post-deploy-caddy] Skip Caddy HTTPS verify: curl not installed"
    return 0
  }

  local s be hp code failed
  failed=0
  for s in "$@"; do
    [[ "$s" == "tls-proxy" ]] && continue
    be="$(compose_first_published_host_port "$s" 2>/dev/null)" || continue
    hp="$(caddy_https_port_for_backend "$be" 2>/dev/null)" || {
      echo "[post-deploy-caddy] No Caddy site for $s (backend :$be not in Caddyfile); skip verify"
      continue
    }
    local vpath
    vpath="$(caddy_verify_path_for_stack "$s")"
    wait_for_stack_backend "$s" "$be" || true
    echo "[post-deploy-caddy] Verify $s via Caddy https://127.0.0.1:${hp}${vpath} (backend 127.0.0.1:${be})"
    code=""
    local max_tries=3 sleep_sec=2
    [[ "$s" == "litellm" ]] && { max_tries=5 sleep_sec=3; }
    for _try in $(seq 1 "$max_tries"); do
      code="$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 6 --max-time 20 "https://127.0.0.1:${hp}${vpath}" || true)"
      if [[ "$code" =~ ^[23] ]] || [[ "$code" == "401" ]] || [[ "$code" == "403" ]]; then
        break
      fi
      [[ "$_try" -lt "$max_tries" ]] && sleep "$sleep_sec"
    done
    if [[ "$code" =~ ^[23] ]] || [[ "$code" == "401" ]] || [[ "$code" == "403" ]]; then
      echo "[post-deploy-caddy] OK $s (HTTP $code)"
    else
      echo "[post-deploy-caddy] FAIL $s — https://127.0.0.1:${hp}/ returned HTTP ${code:-000} (expected 2xx/3xx or 401/403)" >&2
      failed=1
    fi
  done
  if [[ "$failed" -ne 0 ]]; then
    echo "[post-deploy-caddy] One or more Caddy front-door checks failed." >&2
    return 1
  fi
  return 0
}
