# localserver-config

Podman-based stack (hello-world, n8n, TLS proxy) for darragh-pc.

## Setup (once per host)

**1. Generate TLS certificates** (required for HTTPS):
```bash
./scripts/setup-certs.sh
# For thelearningcto.com: ./scripts/setup-certs.sh darragh-pc thelearningcto.com darragh-pc.thelearningcto.com www.thelearningcto.com 192.168.86.237
```
Run on the server. After cert changes: `cd compose/tls-proxy && podman compose restart`. Trust `certs/ca.pem` on clients—see [docs/tls.md](docs/tls.md).

**2. First-time full install** (on the server):
```bash
cd ~/localserver-config
./scripts/deploy.sh
```
Installs Podman, podman-compose, and brings up stacks.

**Adding a new service (Podman + Caddy + LAN):** [docs/ADD-SERVICE.md](docs/ADD-SERVICE.md).

## Deploy (updates)

**From your PC:**
```bash
./scripts/deploy-to-server.sh prod darragh-pc
```
Syncs repo, copies `envs/prod.env` as `.env`, and runs `deploy.sh --compose-only` on the server (no package install).

**Locally:**
```bash
./scripts/deploy-to-server.sh local local
```
Uses `envs/local.env` and deploys on this machine.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup-certs.sh` | Generate TLS certs (run separately, before tls-proxy) |
| `scripts/setup-cockpit.sh` | Install Cockpit + cockpit-podman on the server (one-time) |
| `scripts/deploy.sh` | Deploy stacks on this machine |
| `scripts/deploy-to-server.sh` | `<env> <target>` — sync to remote host and deploy (env selects `envs/<env>.env`) |
| `scripts/check-tls.sh` | TLS diagnostic |
| `tests/check-ports.sh` | Assert ports 8080, 5678, 8443, 8444, 9090, 9443 are listening (run on server) |
| `scripts/setup-windows-hosts.ps1` | Add darragh-pc, darragh-pc.thelearningcto.com → 127.0.0.1 (run as Admin; same-machine access) |
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

Examples: `https://darragh-pc:8443`, `https://darragh-pc.thelearningcto.com:8443` (Route53 → 192.168.86.237)

## Cockpit

Cockpit is installed as a system package (not a container) because it needs D-Bus, systemd, and PAM access.
`deploy-to-server.sh` installs it automatically on first deploy. To install manually:

```bash
ssh darragh-pc "cd ~/localserver-config && sudo ./scripts/setup-cockpit.sh"
```

**Windows Firewall (one-time, on darragh-pc — Admin PowerShell):**
```powershell
New-NetFirewallRule -DisplayName "Cockpit TLS" -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow
```

If Podman binds ports to `[::1]` only, LAN clients also need **IPv4→IPv6** portproxy rules (and similar firewall rules per port). See [WSL2 Podman / IPv6 localhost](docs/NETWORK-CONFIG.md#wsl2-podman-ports-bound-to-ipv6-localhost-only).
