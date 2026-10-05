# Cloudflare edge config for thelearningcto.com: the parts of the public path that live
# in the dashboard rather than in this repo's compose/Caddy files. Request path:
#   browser -> Cloudflare (WAF, Access, Always Use HTTPS) -> tunnel -> Caddy :8097 -> WordPress
# See compose/wordpress/README.md and cloudflare/README.md.

# --- WAF custom rule -------------------------------------------------------------------
# A zone has exactly ONE ruleset per phase, so this resource owns every custom rule in the
# zone. Import the existing ruleset before the first apply or it is replaced (README).
resource "cloudflare_ruleset" "waf_custom" {
  zone_id     = var.zone_id
  name        = "default"
  description = ""
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  # Order matters: rules run top to bottom, and a skip only affects the rules below it.
  rules = [
    {
      # prometheus' blackbox exporter on beeblebox probes https://thelearningcto.com/ (see
      # compose/prometheus/prometheus.yml, job probe-http). The egress IP is dynamic (Verizon
      # FIOS), so match the exporter's own request shape rather than an IP. The UA is spoofable,
      # which is acceptable: all it buys is a GET of the public homepage past the rules below.
      description = "Skip custom rules for the beeblebox uptime probe (GET / from blackbox exporter)"
      action      = "skip"
      enabled     = true
      expression  = "(http.request.method eq \"GET\" and http.request.uri.path eq \"/\" and http.user_agent contains \"Blackbox Exporter\" and http.host in {\"${var.domain}\"})"
      action_parameters = {
        ruleset = "current"
      }
    },
    {
      description = "Block probes for stray .php files; allow WordPress's own entry points"
      action      = var.waf_php_action
      enabled     = true
      expression  = <<-EOT
        (ends_with(http.request.uri.path, ".php")) and not (http.request.uri.path in {"/wp-login.php" "/wp-cron.php" "/xmlrpc.php"} or starts_with(http.request.uri.path, "/wp-admin/"))
      EOT
    },
  ]
}

# --- Access: gate the WordPress admin ---------------------------------------------------
# /wp-admin and /wp-login.php are deliberately not blocked at Caddy, because WordPress
# canonical-redirects admin URLs to WP_SITEURL; Access is the only thing in front of them.
#
# Two apps (one per path), each with ONLY the email-allow policy. Access allow policies are
# OR'd, and an "Everyone" allow policy admits anyone who can finish an IdP login (Google, or
# One-time PIN with any inbox) — that was attached to both apps and is why it was open.
# The policy is a shared, reusable account policy (it also serves the WARP app), so it is
# referenced by id and never managed or edited here.
resource "cloudflare_zero_trust_access_application" "wp_admin" {
  for_each = {
    login = "${var.domain}/wp-login.php"
    admin = "${var.domain}/wp-admin/*"
  }

  account_id                = var.account_id
  name                      = var.domain
  type                      = "self_hosted"
  session_duration          = var.access_session_duration
  allowed_idps              = var.access_allowed_idps
  app_launcher_visible      = true
  auto_redirect_to_identity = false

  destinations = [{ type = "public", uri = each.value }]

  policies = [
    { id = var.access_admin_policy_id, precedence = 1 },
  ]
}

# --- Zone settings ----------------------------------------------------------------------
# HTTPS enforcement has to live at the edge: Caddy :8097 hardcodes X-Forwarded-Proto https
# (to avoid a redirect loop), so WordPress never issues an http->https redirect itself.
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = var.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# --- IP Access Rules --------------------------------------------------------------------
# Cloudflare's recommendation for the beeblebox uptime probe: allow its public egress IP so
# the zone's security features don't challenge or block it. This is an allowlist entry, so
# keep the list to the one host. The residential IP is dynamic, so a stale entry both stops
# protecting the probe and leaves an unrelated customer's address allowed — re-apply on change.
resource "cloudflare_access_rule" "probe" {
  for_each = toset(var.probe_egress_ips)

  zone_id = var.zone_id
  mode    = "whitelist"
  notes   = "beeblebox uptime probe (managed by cloudflare/main.tf)"

  configuration = {
    target = "ip"
    value  = each.value
  }
}
