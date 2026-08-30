#!/usr/bin/env bash
# Run WP-CLI against the wordpress stack.
# Usage: ./scripts/wp-cli.sh <wp subcommand...>
# Example: ./scripts/wp-cli.sh post list --post_type=post --format=count
#
# The official wordpress image ships no wp-cli, so this runs the wordpress:cli image as a
# throwaway container that shares the app container's volumes and compose network.
#
# The DB env vars are passed explicitly and are NOT optional: the generated wp-config.php
# reads them via getenv_docker(), which falls back to DB_HOST="mysql" when they're absent.
# Without them you get "Error establishing a database connection ... at `mysql`", which
# looks like the database is down rather than like a missing environment.
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a

APP_CID="$(podman ps -q --filter "label=io.podman.compose.project=wordpress" \
                        --filter "label=io.podman.compose.service=wordpress" | head -1)"
[[ -n "$APP_CID" ]] || {
  echo "ERROR: wordpress app container not running. Try: ./scripts/deploy-stack.sh wordpress" >&2
  exit 1
}

# Migration inputs (WXR export, media tarball) if staged; read-only.
mounts=()
[[ -d "$HOME/wp-migration" ]] && mounts+=(-v "$HOME/wp-migration:/migration:ro")

# Run as the uid that owns the site files, not the cli image's own www-data.
# The two images disagree: wordpress:php8.3-apache is Debian (www-data = uid 33), while
# wordpress:cli is Alpine (www-data = uid 82). Without this, anything that writes —
# `plugin install`, `import`, `media import` — fails with a bare "Error: No plugins
# installed" that looks like a download problem rather than a permissions one.
SITE_UID="$(podman exec "$APP_CID" stat -c '%u' /var/www/html 2>/dev/null || echo 33)"
SITE_GID="$(podman exec "$APP_CID" stat -c '%g' /var/www/html 2>/dev/null || echo 33)"

exec podman run --rm -i \
  --network wordpress_default \
  --volumes-from "$APP_CID" \
  --user "${SITE_UID}:${SITE_GID}" \
  -e WORDPRESS_DB_HOST=db:3306 \
  -e WORDPRESS_DB_NAME=wordpress \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD="${WORDPRESS_DB_PASSWORD:?WORDPRESS_DB_PASSWORD not set — is .env present?}" \
  "${mounts[@]}" \
  docker.io/library/wordpress:cli wp --path=/var/www/html "$@"
