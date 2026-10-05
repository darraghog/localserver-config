# cloudflare — edge config as code

Terraform for the parts of thelearningcto.com that live at Cloudflare rather than in this
repo's compose/Caddy files. Request path and why each piece exists:
[`compose/wordpress/README.md`](../compose/wordpress/README.md).

| Resource | What it does |
|---|---|
| `cloudflare_ruleset.waf_custom` | WAF custom rule: stray `.php` probes blocked; `/wp-login.php`, `/wp-cron.php`, `/xmlrpc.php`, `/wp-admin/*` exempt |
| `cloudflare_zero_trust_access_application.wp_admin` | Two Access apps (`/wp-login.php`, `/wp-admin/*`), each with only the admin-email policy |
| `cloudflare_access_rule.probe` | IP Access Rule allowing beeblebox's egress IP (needs token scope Zone Firewall Services Edit) |
| `cloudflare_zone_setting.always_use_https` | The only place http→https happens (Caddy `:8097` hardcodes `X-Forwarded-Proto https`) |

Not managed here: the tunnel itself and its DNS (`cloudflared/`), and anything else in the zone.

## Running it

Terraform runs from the laptop in a container (no install), via `scripts/cloudflare.sh`:

```bash
cp cloudflare/terraform.tfvars.example cloudflare/terraform.tfvars   # fill in IDs + emails
# add CLOUDFLARE_API_TOKEN to .env (scopes listed in .env.example)
./scripts/cloudflare.sh init
./scripts/cloudflare.sh plan
./scripts/cloudflare.sh apply
```

`./scripts/deploy-to-server.sh prod ...` runs a **plan only** at the end and warns on drift. It
never applies; edge changes are a deliberate `apply`. `cloudflare/` is excluded from the rsync
to the server.

## First run: import before you apply

The dashboard already holds the live config. Applying against empty state would **replace the
zone's whole custom-rules ruleset** and create a duplicate Access app. Import first, then
`plan` and reconcile until it shows no changes (set `waf_php_action` and the emails to match):

```bash
# WAF: find the ruleset id of phase http_request_firewall_custom
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/zones/<zone_id>/rulesets | jq '.result[] | {id,phase}'

# v5 import ids need the zones/ or accounts/ prefix
./scripts/cloudflare.sh import cloudflare_ruleset.waf_custom zones/<zone_id>/<ruleset_id>
./scripts/cloudflare.sh import 'cloudflare_zero_trust_access_application.wp_admin["login"]' accounts/<account_id>/<wp-login app id>
./scripts/cloudflare.sh import 'cloudflare_zero_trust_access_application.wp_admin["admin"]' accounts/<account_id>/<wp-admin app id>
./scripts/cloudflare.sh import cloudflare_zone_setting.always_use_https zones/<zone_id>/always_use_https
```

The email-allow Access policy is a shared reusable policy (the WARP app uses it too), so it is
referenced by id (`access_admin_policy_id`), never imported or managed. Do not attach an
"Everyone" allow policy to these apps: Access allow policies are OR'd, and Everyone admits
anyone who completes an IdP login, including One-time PIN with any inbox.

If a resource doesn't exist yet in the dashboard, skip its import and let `apply` create it.
Any *other* custom WAF rules in the zone must be added to `main.tf` before apply, or apply
removes them.

## State

Local file `cloudflare/terraform.tfstate` (gitignored, never rsynced). Nothing backs it up; if it
is lost, re-import as above. Move to a remote backend if a second machine ever needs to apply.
