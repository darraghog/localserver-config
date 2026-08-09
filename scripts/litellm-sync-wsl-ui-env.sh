#!/usr/bin/env bash
# Set LiteLLM Admin UI credentials to the current WSL/Linux user in envs/<env>.env
#
# Usage:
#   ./scripts/litellm-sync-wsl-ui-env.sh dev              # prompt for WSL login password
#   LITELLM_UI_PASSWORD='...' ./scripts/litellm-sync-wsl-ui-env.sh dev
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${1:?env name (e.g. dev)}"
ENV_FILE="$REPO_ROOT/envs/${ENV_NAME}.env"
USER_NAME="$(whoami)"

[[ -f "$ENV_FILE" ]] || {
  echo "ERROR: $ENV_FILE not found" >&2
  exit 1
}

if [[ -z "${LITELLM_UI_PASSWORD:-}" ]]; then
  read -rsp "WSL login password for ${USER_NAME}: " LITELLM_UI_PASSWORD
  echo
  [[ -n "$LITELLM_UI_PASSWORD" ]] || {
    echo "ERROR: empty password" >&2
    exit 1
  }
fi

upsert() {
  local key="$1" val="$2" file="$3"
  python3 - "$key" "$val" "$file" <<'PY'
import re, sys
key, val, path = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
line = f'{key}={val}\n'
pat = re.compile(rf'^{re.escape(key)}=.*$', re.M)
if pat.search(text):
    text = pat.sub(line.rstrip(), text)
else:
    if not text.endswith("\n"):
        text += "\n"
    text += line
open(path, "w", encoding="utf-8").write(text)
PY
}

# Quote password if it contains shell-special characters
if [[ "$LITELLM_UI_PASSWORD" == *[#\$\"\'\ \	]* ]]; then
  esc="${LITELLM_UI_PASSWORD//\"/\\\"}"
  upsert "LITELLM_UI_PASSWORD" "\"$esc\"" "$ENV_FILE"
else
  upsert "LITELLM_UI_PASSWORD" "$LITELLM_UI_PASSWORD" "$ENV_FILE"
fi
upsert "LITELLM_UI_USERNAME" "$USER_NAME" "$ENV_FILE"

echo "[litellm-sync-wsl-ui-env] Set LITELLM_UI_USERNAME=$USER_NAME in envs/${ENV_NAME}.env"
