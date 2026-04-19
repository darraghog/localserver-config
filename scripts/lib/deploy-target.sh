# shellcheck shell=bash
# Shared target detection for deploy scripts.
# Source after setting: TARGET, SSH_DEST (typically SSH_DEST="${DEPLOY_SSH_DEST:-$TARGET}").

ip_on_this_machine() {
  local ip="$1"
  ip addr show 2>/dev/null | grep -qE "inet ${ip}/" && return 0
  ip -brief addr show 2>/dev/null | awk '{print $3}' | tr ',' '\n' | grep -qE "^${ip}/" && return 0
  return 1
}

# Trim whitespace / CR (used by deploy-to-server for cert SAN tokens).
trim_cert_token() {
  local x="$1"
  x="${x//$'\r'/}"
  x="${x#"${x%%[![:space:]]*}"}"
  x="${x%"${x##*[![:space:]]}"}"
  printf '%s' "$x"
}

# True when deploy should run locally (no rsync/ssh): target is "local", loopback, this hostname, etc.
deploy_target_is_this_host() {
  [[ "$TARGET" == "local" ]] && return 0

  local check_host="$TARGET"
  [[ "$TARGET" == *@* ]] && check_host="${TARGET#*@}"
  [[ "$check_host" == "local" ]] && return 0

  local conn_host="$SSH_DEST"
  [[ "$SSH_DEST" == *@* ]] && conn_host="${SSH_DEST#*@}"

  if [[ "$conn_host" =~ ^127\. ]] || [[ "$conn_host" == "::1" ]]; then
    return 0
  fi

  if [[ "$conn_host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && ip_on_this_machine "$conn_host"; then
    return 0
  fi

  local first
  first="$(getent ahosts "$check_host" 2>/dev/null | awk 'NF && $1 !~ /^#/ { print $1; exit }')"
  if [[ -n "$first" ]] && { [[ "$first" =~ ^127\. ]] || [[ "$first" == "::1" ]]; }; then
    return 0
  fi

  local h sh
  h="$(hostname)"
  sh="$(hostname -s 2>/dev/null || true)"
  [[ -z "$sh" ]] && sh="$h"
  if [[ "${check_host,,}" == "${h,,}" ]] || [[ "${check_host,,}" == "${sh,,}" ]]; then
    return 0
  fi

  return 1
}
