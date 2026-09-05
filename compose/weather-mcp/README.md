# weather-mcp — deployment notes

How this platform publishes the weather MCP server. The application itself is owned by a
separate repo (`~/dev/claude/weather`) and vendored into this directory by
[`sync-app.sh`](sync-app.sh); this file covers only what deploying it here involves.

Platform-side background: [`docs/NETWORK-CONFIG.md`](../../docs/NETWORK-CONFIG.md)
(exposure tiers, the `:8090` path router, and the OAuth-metadata capability this service uses).
Model entry: `ac-weather-mcp` in [`architecture/model.yaml`](../../architecture/model.yaml).

## public :443 path mounts

The weather MCP server (`compose/weather-mcp`, source vendored from
`~/dev/claude/weather`) is published on the existing public Funnel. Three mounts,
all additive — n8n's root entry is untouched:

```
/weather                                          -> 127.0.0.1:8095   Caddy allowlist -> :8094
/.well-known/oauth-authorization-server/weather   -> 127.0.0.1:8094/.well-known/oauth-authorization-server
/.well-known/oauth-protected-resource/weather/mcp -> 127.0.0.1:8094/.well-known/oauth-protected-resource/mcp
```

**Why `:443` and not a dedicated port.** Same lesson as n8n's `:10000` failure
above — a public MCP endpoint has to be on `:443` for Claude's connector
infrastructure to reach it.

**Why the metadata gets its own mounts.** `--set-path` strips its prefix, so the
container serves everything at `/` and only the advertised URLs carry `/weather`
(all derived from `WEATHER_MCP_ISSUER_URL`). But RFC 8414 puts
authorization-server metadata at the **host root**, which n8n owns — and n8n's
SPA answers every unmatched path with `200 text/html`. That is worse than a 404:
the client gets a success it cannot parse and has nothing to fall back from. So
those URLs are claimed explicitly. Their proxy targets carry a path, which
Tailscale re-applies when the stripped path is empty — verified on a scratch
tailnet-only port before touching `:443`.

**Why only part of the app is published.** The app's bearer/OAuth check wraps
only its `/mcp` mount, so the Flask GUI and `/api/*` routes are unauthenticated,
and `/api/city-coordinates` proxies to `nominatim.openstreetmap.org`, whose usage
policy bans abusive IPs. The `:8095` Caddy site the funnel points at passes only
MCP, the OAuth endpoints, `/login`, the well-known documents and `/health`. The
GUI stays off the public leg: it is reachable on the LAN front door at `:8448` and
on the tailnet at `:8090/weather` (the path router above), both of which require
either the LAN or the VPN to reach.

### Regression check

`tailscale funnel status`'s **text** output pads the mount column to the longest
entry, so adding a long mount re-pads the `/` line and a byte-identical text diff
is impossible. Use the JSON:

```bash
ssh beeblebox 'tailscale funnel status --json' | jq -S \
  '{root:       .Web["beeblebox.taile98462.ts.net:443"].Handlers["/"],
    claudemock: .Web["beeblebox.taile98462.ts.net:443"].Handlers["/claudemock"],
    funnel:     .AllowFunnel,
    tcp:        .TCP}'
```

This object must be identical before and after any funnel change.

> **`tailscale funnel reset` and `tailscale serve reset` are banned on beeblebox.**
> They clear the entire ServeConfig, taking n8n's root, `/claudemock`, the `:8090`
> router and litellm's `:8092` with them. To remove one mount:
> `tailscale funnel --https=443 --set-path=/weather off`.

---
