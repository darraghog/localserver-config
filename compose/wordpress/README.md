# wordpress — deployment notes

How this platform publishes thelearningcto.com. Platform-side background:
[`docs/NETWORK-CONFIG.md`](../../docs/NETWORK-CONFIG.md).
Model entry: `ac-wordpress` in [`architecture/model.yaml`](../../architecture/model.yaml).

## Running this stack outside production

`WP_HOME` and `WP_SITEURL` are read from `.env` by `config/config-extra.php` and default to
`https://thelearningcto.com` when unset — so production needs no configuration and behaves exactly
as it did when they were hardcoded. A non-prod instance sets both to its own Caddy address
(`envs/local.env` uses `https://127.0.0.1:8449`), otherwise WordPress canonical-redirects every
request to the production domain and the instance cannot be browsed at all.

Set them to the same value. The database is separate per environment, so a non-prod instance is a
fresh install, not a copy of the live site.

## public on thelearningcto.com via Cloudflare Tunnel

**Added 2026-08-30**, migrating the blog off the free WordPress.com plan
(`thelearningcto.wordpress.com`) onto beeblebox. This is the first service here published
on a **custom domain**, and the first that does not use Tailscale Funnel.

### Why Cloudflare Tunnel and not Funnel

Funnel can only ever serve `beeblebox.taile98462.ts.net`. It has no mechanism for a custom
domain, so it cannot host this blog at all. The remaining options were the two this document
already weighed: a direct `:443` port-forward (listed above as "Option to Avoid" — inbound
exposure of the home network, plus dynamic-IP fragility on Verizon FIOS) or an outbound-only
tunnel. Cloudflare Tunnel keeps the "no inbound ports" property Funnel gave us.

Everything already on Funnel — n8n at `:443` root, `/weather`, `/claudemock`, the `:8090`
router, litellm's `:8092` — is untouched by this and stays on Funnel. The two systems run
side by side. **Verify with the JSON regression check above after any tunnel work**; adding
the WordPress tunnel left it identical.

### Request path

```
browser -> Cloudflare edge (TLS terminates here, Access gates /wp-admin)
        -> cloudflared (outbound QUIC, no inbound port)
        -> Caddy :8097  (loopback, plain HTTP, blocks /xmlrpc.php)
        -> WordPress :8096 (loopback) -> MariaDB (compose network, no host port)
```

`cloudflared` runs as the **user** unit `localserver-cloudflared.service` (config in
`cloudflared/config.yml`), matching this repo's rootless-podman + linger model — a tunnel
dials out, so it needs neither root nor `cloudflared service install`.

### Two traps this setup walks into, both already handled

1. **HTTPS detection.** cloudflared and Caddy both speak plain HTTP to the container while
   `WP_SITEURL` says `https://`. WordPress then decides the request was insecure and
   redirect-loops against its own canonical URL. The `:8097` Caddy site therefore sets
   `header_up X-Forwarded-Proto https` **hardcoded** — `{scheme}` would resolve to `http`
   here and overwrite what Cloudflare sent. Same reasoning as the `:8092` litellm block.
2. **Compose eats `$_SERVER`.** The wp-config additions live in
   `compose/wordpress/config/config-extra.php`, mounted as a directory and pulled in by a
   one-line `WORDPRESS_CONFIG_EXTRA=require ...`. Putting the PHP inline in `compose.yaml`
   fails silently: Compose treats `$_SERVER` as a variable reference and blanks it. The
   official image `eval()`s `WORDPRESS_CONFIG_EXTRA` at runtime rather than inlining it into
   wp-config.php, so edits to that file take effect on redeploy without regenerating config.

### Admin access: Cloudflare Access, not a second hostname

`/wp-admin/*` and `/wp-login.php` are deliberately **not** blocked at Caddy. WordPress
canonical-redirects every admin URL to `WP_SITEURL`, so serving admin on a different
hostname (a tailnet port, say) makes the login form post back to the public URL and fail —
the same category of problem as litellm's hardcoded root paths, but with redirects rather
than assets. Admin is gated at the Cloudflare edge by Access instead (team
`tight-sun-921f`). The LAN `:8449` site exists for break-glass checks only; it redirects to
the public URL like everything else.

### WP-CLI

The official wordpress image ships no wp-cli. Use `./scripts/wp-cli.sh <subcommand>`, which
runs the `wordpress:cli` image against the app container's volumes. It passes the DB env
explicitly (wp-config falls back to `DB_HOST=mysql` otherwise, which reads as "database is
down") and runs as the **uid owning the site files**: the apache image is Debian
(`www-data` = 33) while the cli image is Alpine (`www-data` = 82), and the mismatch surfaces
as a misleading `Error: No plugins installed`.

### HTTPS enforcement lives at the edge, not at the origin

`http://` → `https://` redirection is done by Cloudflare's **Always Use HTTPS** (SSL/TLS → Edge
Certificates), and it **has to be**. The `:8097` site hardcodes `header_up X-Forwarded-Proto https`
to prevent the redirect loop described above, so WordPress believes every request already arrived
over TLS and will never issue an http→https redirect itself. Passing the edge's real
`X-Forwarded-Proto` through instead would restore that ability and reintroduce the loop risk — the
wrong trade.

The confusing symptom if the toggle is off: `http://www.thelearningcto.com` redirects to https
correctly while `http://thelearningcto.com` serves 200 in the clear and the browser says "Not
secure". Those are two different mechanisms — the `www` redirect is WordPress canonicalising the
*hostname* (which happens to target the https `WP_SITEURL`), not a scheme upgrade. Don't go hunting
for a Caddy or WordPress bug; check the Cloudflare toggle.

### Zone activation gotcha

A Cloudflare zone in **`pending`** status serves its unproxied records (MX, TXT) but *not*
its proxied ones. Since tunnel routes are proxied CNAMEs, the symptom is email working
perfectly while the website NXDOMAINs — even though `cloudflared tunnel route dns` reported
success and the records are visibly present in the dashboard. Check with the zone API
(`status` field); the fix is Cloudflare re-verifying the nameservers, not anything on this
host. The tunnel's own scoped token cannot trigger `activation_check`.

---
