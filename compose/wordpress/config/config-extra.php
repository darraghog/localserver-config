<?php
/**
 * Extra wp-config.php settings for thelearningcto.com.
 *
 * Loaded via WORDPRESS_CONFIG_EXTRA in compose.yaml, which sets a one-line
 * `require` pointing here. The PHP deliberately lives in this file rather than
 * inline in compose.yaml: Compose performs ${VAR} substitution on environment
 * values, and it treats `$_SERVER` as a reference to a variable named _SERVER,
 * silently blanking it. That would leave broken PHP in wp-config.php.
 *
 * The directory (not this file) is bind-mounted, so rsync replacing the file on
 * deploy is picked up — see the single-file bind-mount footgun documented for
 * the Caddyfile in docs/ADD-SERVICE.md.
 *
 * This is `require`d at runtime on every request, so edits here take effect on
 * redeploy without regenerating wp-config.php.
 */

/* Canonical site URL. WordPress bakes this into every generated link and
   canonical-redirects to it, which is why the LAN :8449 door bounces to it in prod.

   Overridable per environment so a non-prod instance can be browsed at its own
   address instead of redirecting to production. compose.yaml passes WP_HOME and
   WP_SITEURL through from .env, defaulting to the public URL — so an environment
   that sets neither behaves exactly as it did when these were hardcoded.

   plain getenv(), not the image's getenv_docker(): this file is required from
   wp-config.php and must not depend on that helper still existing. An empty value
   falls back too, so a blank line in .env cannot produce an empty WP_HOME. */
define( 'WP_HOME',    getenv( 'WP_HOME' )    ?: 'https://thelearningcto.com' );
define( 'WP_SITEURL', getenv( 'WP_SITEURL' ) ?: 'https://thelearningcto.com' );

/* Cloudflare Tunnel and Caddy both speak plain HTTP to this container while the
   site URL above is https. Without this, WordPress decides the request was
   insecure and redirect-loops against its own canonical URL on the very first
   hit. The Caddy :8097 site hardcodes X-Forwarded-Proto: https for this reason.

   The official image's generated wp-config.php already does this a few lines
   above where it eval()s this file (a looser strpos check). Kept here anyway so
   the behaviour is explicit and survives an image that drops it. */
if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https' ) {
	$_SERVER['HTTPS'] = 'on';
}

/* Real client IPs. Cloudflare -> cloudflared -> Caddy means REMOTE_ADDR is
   always loopback otherwise, which breaks login/comment rate limiting and makes
   every log line look like it came from the server itself. */
if ( isset( $_SERVER['HTTP_CF_CONNECTING_IP'] ) ) {
	$_SERVER['REMOTE_ADDR'] = $_SERVER['HTTP_CF_CONNECTING_IP'];
}

/* Publicly reachable install: no editing PHP from the browser. */
define( 'DISALLOW_FILE_EDIT', true );
