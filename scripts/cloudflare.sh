#!/usr/bin/env bash
# Run Terraform against cloudflare/ (WAF rule, Access app, zone settings for thelearningcto.com).
# Usage: ./scripts/cloudflare.sh <terraform subcommand...>
# Examples:
#   ./scripts/cloudflare.sh init
#   ./scripts/cloudflare.sh plan
#   ./scripts/cloudflare.sh apply
#
# Terraform is not installed on the host; like wp-cli.sh this runs the official image as a
# throwaway container, so there is nothing to bootstrap. State is a local file in cloudflare/
# (gitignored, covered by nothing — back it up or re-import; see cloudflare/README.md).
#
# Needs in .env (or the environment):
#   CLOUDFLARE_API_TOKEN   scoped token — Zone:WAF Edit, Zone:Zone Settings Edit,
#                          Account:Access Apps and Policies Edit
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN not set — add it to .env (see .env.example)}"
[[ -f "$REPO_ROOT/cloudflare/terraform.tfvars" ]] || {
  echo "ERROR: cloudflare/terraform.tfvars missing. cp cloudflare/terraform.tfvars.example cloudflare/terraform.tfvars" >&2
  exit 1
}

# Pass the token by name only, so it never appears in the process list.
exec podman run --rm -i \
  --userns=keep-id \
  -v "$REPO_ROOT/cloudflare:/work" -w /work \
  -e CLOUDFLARE_API_TOKEN \
  -e TF_IN_AUTOMATION=1 \
  docker.io/hashicorp/terraform:1.9 "$@"
