# localserver-config

Podman-based stack (hello-world, n8n, TLS proxy) for a single host or homelab.

## Layout

- **`scripts/`** — day-to-day updates: deploy stacks, certs, checks. **No sudo.**
- **`scripts/sudo/`** — one-time or privileged host setup (Podman install, systemd linger, Cockpit, `/etc/hosts`).
- **`compose/stack-order`** — ordered stack names for `./scripts/deploy.sh`; use `./scripts/deploy-stack.sh <name>` to update stacks independently.
- **`./scripts/add-service.sh`** — scaffolds a new `compose/<name>/` stack, a `localserver-<name>.service` unit, and a `stack-order` line (see [docs/ADD-SERVICE.md](docs/ADD-SERVICE.md)).

## Setup (once per host)

**1. Host bootstrap** (Podman, base packages, podman-compose, systemd user units — uses `sudo` internally):

```bash
cd ~/localserver-config
./scripts/sudo/bootstrap-host.sh
```

**2. Configure secrets** — copy `.env.example` to `.env` (or use `envs/<name>.env` with `deploy-to-server.sh`) and set passwords / `N8N_ENCRYPTION_KEY`.

**3. Generate TLS certificates** (required for HTTPS):

```bash
./scripts/setup-certs.sh
# With extra SANs: ./scripts/setup-certs.sh myserver myserver.example.com www.example.com 192.168.1.10
```

Run on the server. After cert changes: `cd compose/tls-proxy && podman compose restart`. Trust `certs/ca.pem` on clients—see [docs/tls.md](docs/tls.md).

**4. Bring up stacks** (no sudo):

```bash
./scripts/deploy.sh
```

**Adding a new service (Podman + Caddy + LAN):** [docs/ADD-SERVICE.md](docs/ADD-SERVICE.md).

## Deploy (updates)

**From your PC:**

```bash
./scripts/deploy-to-server.sh prod myserver.example.net
# sshd on a non-default port (e.g. 2222 on some hosts):
./scripts/deploy-to-server.sh prod myserver.example.net 2222
# Wrong DNS/hosts for the target — real SSH destination (port 22 if omitted):
# DEPLOY_SSH_DEST=user@192.168.1.10 ./scripts/deploy-to-server.sh dev laptop
```

If **`<target>` is this machine** (hostname matches, name resolves to `127.*`/`::1` as on WSL, or `DEPLOY_SSH_DEST` is loopback / this host’s LAN IP), the script **deploys like `local local`**: no rsync/ssh, same steps as below.

Remote deploy otherwise: syncs repo, copies `envs/<env>.env` as `.env`, regenerates TLS on the server (SANs include `$(hostname)`, `.local`, first `hostname -I` address, **and your deploy `<target>` host part**; optional **`DEPLOY_CERT_EXTRA_SANS`** for more names or a LAN IP), runs `deploy.sh`, then **post-deploy checks**: always `tests/check-ports.sh --core-only` (8080, 5678). **TLS/Caddy port checks** (`tests/check-ports.sh` full) and **`scripts/check-tls.sh`** run **only when `env` is `prod` and `certs/server.pem` exists** on the target (after deploy). Cockpit is **not** installed or reconfigured by this script.

**Cockpit (optional, requires sudo on the server):**

```bash
./scripts/sudo/deploy-cockpit.sh myserver.example.net
```

**Locally:**

```bash
./scripts/deploy-to-server.sh local local
```

Uses `envs/local.env` and deploys on this machine.

## Scripts

| Path | Purpose |
|------|---------|
| `scripts/sudo/bootstrap-host.sh` | First-time: apt base, Podman, podman-compose, systemd units, `loginctl` linger (`sudo` where needed) |
| `scripts/sudo/setup-cockpit.sh` | Install/configure Cockpit + cockpit-podman (called by `scripts/sudo/deploy-cockpit.sh`) |
| `scripts/sudo/deploy-cockpit.sh` | `<target>` — `local` or SSH host; Cockpit only |
| `scripts/sudo/setup-wsl-hosts.sh` | Append `/etc/hosts` in WSL (sudo) — `LOCALSERVER_HOSTS_ENTRY` or args `<ip> <names...>`; optional `LOCALSERVER_HOSTS_MARKER` |
| `scripts/setup-certs.sh` | Generate TLS certs (run separately, before tls-proxy) |
| `scripts/deploy.sh` | Update all stacks in `compose/stack-order` (no sudo) |
| `scripts/deploy-stack.sh` | Deploy only named stack(s): `./scripts/deploy-stack.sh n8n` or `hello-world tls-proxy` |
| `scripts/add-service.sh` | Scaffold `compose/<name>/`, systemd unit, and `stack-order` entry |
| `scripts/start-stack.sh` | `up` / `down` for one stack (used by systemd and deploy scripts) |
| `compose/stack-order` | Lines = stack directory names; order used by `deploy.sh` |
| `scripts/deploy-to-server.sh` | `<env> <target> [<ssh-port>]` — remote sync+deploy, or **local** if target is this host; `DEPLOY_SSH_DEST`, `DEPLOY_SSH_PORT` |
| `scripts/check-tls.sh` | TLS diagnostic |
| `scripts/check-updates.py` | Report pinned image tags vs newest published, plus compose ↔ `model.yaml` drift (read-only; `--offline`, `--stack`, `--strict`). Tests: `python3 -m unittest discover -s tests` |
| `tests/check-ports.sh` | Port checks (WSL-side only — does not test Windows LAN reachability); use `--core-only` for 8080/5678 only; full list includes Caddy TLS + Cockpit |
| `scripts/setup-windows-hosts.ps1` | Windows hosts file (requires `LOCALSERVER_HOST_PRIMARY`; optional `LOCALSERVER_HOST_SECONDARY`; Admin) |
| `scripts/setup-windows-port-forward.ps1` | Forward Windows 8443/8444 → WSL (alternative to hosts; run as Admin) |
| `scripts/setup-windows-podman-lan-ports.ps1` | Classic Windows Firewall + IPv4→IPv6 portproxy: ports from `compose/tls-proxy/Caddyfile` + `compose/windows-lan-extra-ports.txt`; schedule at startup (Admin). **Mirrored networking also needs a Hyper-V firewall rule per port** — not covered by this script yet, see [docs/NETWORK-CONFIG.md](docs/NETWORK-CONFIG.md#mirrored-wsl-networking-hyper-v-firewall-separate-from-windows-firewall) |

## Stacks

| Stack | Ports | Description |
|-------|-------|-------------|
| hello-world | 8080, 8443 | nginx test |
| n8n | 5678, 8444 | Workflow automation (SQLite) |
| tic-tac-toe | 8091 (host-internal), 8445 | Reference app proving path-based routing |
| claude-mock-test | 8093 (host-internal), 8446 | Static Claude Professional Architect mock test (nginx) |
| litellm | 4000 (host-internal), 8447, 8092 (tailnet front, loopback) | LLM proxy + Postgres; serves under `/litellm` (`SERVER_ROOT_PATH`) |
| weather-mcp | 8094 (host-internal), 8448, 8095 (public front, loopback) | MCP tool server plus a private GUI |
| wordpress | 8096 (host-internal), 8449, 8097 (public front, loopback) | thelearningcto.com blog — WordPress + MariaDB, public via Cloudflare Tunnel |
| gqldb | 3052 (host-internal), 8450, 8098 (tailnet front, loopback); 60061 (host-internal, gRPC) | Ultipa GQLDB graph database + web console, two containers in one pod |
| tls-proxy | LAN TLS 8443–8450 and 9443; loopback-only 8090 (tailnet path router), 8092 (litellm), 8098 (gqldb), 8095 (weather public front), 8097 (wordpress public front) | Caddy HTTPS reverse proxy |
| Cockpit | 9090 (internal), 9443 (TLS) | Podman container/pod management UI |

## URLs

Plain HTTP, published on the LAN by the stack itself — only these two; every other stack
publishes to `HOST_INTERNAL_IP` and is reachable through Caddy or not at all:

- http://&lt;host&gt;:8080 — hello-world
- http://&lt;host&gt;:5678 — n8n

HTTPS through Caddy, using the private CA (trust `certs/ca.pem` — see [docs/tls.md](docs/tls.md)):

| URL | Service |
|-----|---------|
| https://&lt;host&gt;:8443 | hello-world |
| https://&lt;host&gt;:8444 | n8n |
| https://&lt;host&gt;:8445 | tic-tac-toe |
| https://&lt;host&gt;:8446 | claude-mock-test |
| https://&lt;host&gt;:8447 | litellm — admin UI at `/ui/`, API at `/v1` (Caddy adds the `/litellm` root path) |
| https://&lt;host&gt;:8448 | weather-mcp GUI |
| https://&lt;host&gt;:8449 | wordpress |
| https://&lt;host&gt;:8450 | gqldb — GQLDB Manager console (own login; not network-trusted) |
| https://&lt;host&gt;:9443/cockpit/ | Cockpit (Linux system user credentials) |

Credentials come from `.env` — there are no defaults, and `deploy.sh` refuses to deploy n8n or
WordPress without them.

Ports `8090`, `8092`, `8095`, `8097` and `8098` are **not** in that table on purpose: they bind loopback
only and exist to be mounted by Tailscale or Cloudflare, not visited directly.

`60061` is absent for a different reason: it is the graph database's raw gRPC port, which is
not HTTP and has no front door at all. Its only caller is the console container beside it.

Examples: `https://myserver:8443`, `https://myserver.example.com:8443` (after DNS or `/etc/hosts` points at the Podman host).

## Tailnet URLs (beeblebox)

Path names instead of a port per service — see [docs/NETWORK-CONFIG.md](docs/NETWORK-CONFIG.md#tailnet-path-routing) and [docs/ADD-SERVICE.md](docs/ADD-SERVICE.md#9-tailnet-path-routing-tailscale-beeblebox).

**The list of services and their URLs is not repeated here.** It is data in
[`architecture/model.yaml`](architecture/model.yaml) — the `as-*` application services, each with its
`endpoint` and exposure tier — rendered by `architecture/overview.html`, and validated on every
deploy. Four exposure tiers are in use:

- **Tailnet-only, path router `:8090`** — most services; one port, a path each.
- **Tailnet-only, dedicated port** — kept as a fallback where path-mounting was hard-won: litellm
  answers on `:8092` as well as at `/litellm` (see NETWORK-CONFIG.md).
- **Public via Tailscale Funnel on `:443`** — keep public MCP/webhook endpoints on `:443`, not a
  dedicated port: hosted connector infra (e.g. claude.ai) has been observed failing to reach
  non-standard ports.
- **Public via Cloudflare Tunnel on a custom domain** — Funnel can only ever serve
  `*.ts.net`, so anything on its own domain needs the tunnel instead
  ([`cloudflared/config.yml.in`](cloudflared/config.yml.in)).

## Cockpit

Cockpit is installed as a system package (not a container) because it needs D-Bus, systemd, and PAM access.
It is **separate** from Podman stack deploy. From your PC (after the repo exists on the server):

```bash
./scripts/sudo/deploy-cockpit.sh myserver.example.net
```

On the server directly:

```bash
cd ~/localserver-config && ./scripts/sudo/deploy-cockpit.sh local
```

Low-level entrypoint: `sudo ./scripts/sudo/setup-cockpit.sh`.

**Windows Firewall (one-time on the Windows host — Admin PowerShell):**

```powershell
New-NetFirewallRule -DisplayName "Cockpit TLS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow
```

If Podman binds ports to `[::1]` only, LAN clients also need **IPv4→IPv6** portproxy rules (and similar firewall rules per port). See [WSL2 Podman / IPv6 localhost](docs/NETWORK-CONFIG.md#wsl2-podman-ports-bound-to-ipv6-localhost-only).

**Mirrored WSL networking (`.wslconfig`: `networkingMode=mirrored`):** classic Windows Firewall rules alone are not enough — LAN clients also need a matching **Hyper-V firewall** rule per port (`New-NetFirewallHyperVRule`), and the WSL host can never reach its own hostname/LAN IP (use `localhost` there; test LAN reachability from another device). See [Mirrored WSL networking: Hyper-V firewall](docs/NETWORK-CONFIG.md#mirrored-wsl-networking-hyper-v-firewall-separate-from-windows-firewall).
