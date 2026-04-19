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
| `tests/check-ports.sh` | Port checks; use `--core-only` for 8080/5678 only; full list includes Caddy TLS + Cockpit |
| `scripts/setup-windows-hosts.ps1` | Windows hosts file (requires `LOCALSERVER_HOST_PRIMARY`; optional `LOCALSERVER_HOST_SECONDARY`; Admin) |
| `scripts/setup-windows-port-forward.ps1` | Forward Windows 8443/8444 → WSL (alternative to hosts; run as Admin) |
| `scripts/setup-windows-podman-lan-ports.ps1` | Firewall + IPv4→IPv6 portproxy: ports from `compose/tls-proxy/Caddyfile` + `compose/windows-lan-extra-ports.txt`; schedule at startup (Admin) |

## Stacks

| Stack | Ports | Description |
|-------|-------|-------------|
| hello-world | 8080, 8443 | nginx test |
| n8n | 5678, 8444 | Workflow automation (SQLite) |
| tls-proxy | 8443, 8444, 9443 | Caddy HTTPS reverse proxy |
| Cockpit | 9090 (internal), 9443 (TLS) | Podman container/pod management UI |

## URLs

- http://&lt;host&gt;:8080, https://&lt;host&gt;:8443 — hello-world
- http://&lt;host&gt;:5678, https://&lt;host&gt;:8444 — n8n (admin / changeme)
- https://&lt;host&gt;:9443 — Cockpit (login with Linux system user credentials)

Examples: `https://myserver:8443`, `https://myserver.example.com:8443` (after DNS or `/etc/hosts` points at the Podman host).

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
