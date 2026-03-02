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

## Deploy (updates)

**From your PC:**
```bash
./scripts/deploy-to-server.sh darragh-pc
```
Syncs repo and runs `deploy.sh --compose-only` on the server (no package install).

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup-certs.sh` | Generate TLS certs (run separately, before tls-proxy) |
| `scripts/deploy.sh` | Deploy stacks on this machine |
| `scripts/deploy-to-server.sh` | Sync to remote host and deploy |
| `scripts/check-tls.sh` | TLS diagnostic |
| `tests/check-ports.sh` | Assert ports 8080, 5678, 8443, 8444 are listening (run on server) |
| `scripts/setup-windows-hosts.ps1` | Add darragh-pc, darragh-pc.thelearningcto.com → 127.0.0.1 (run as Admin; same-machine access) |
| `scripts/setup-windows-port-forward.ps1` | Forward Windows 8443/8444 → WSL (alternative to hosts; run as Admin) |

## Stacks

| Stack | Ports | Description |
|-------|-------|-------------|
| hello-world | 8080, 8443 | nginx test |
| n8n | 5678, 8444 | Workflow automation (SQLite) |
| tls-proxy | 8443, 8444 | Caddy HTTPS reverse proxy |
## URLs

- http://&lt;host&gt;:8080, https://&lt;host&gt;:8443 — hello-world
- http://&lt;host&gt;:5678, https://&lt;host&gt;:8444 — n8n (admin / changeme)

Examples: `https://darragh-pc:8443`, `https://darragh-pc.thelearningcto.com:8443` (Route53 → 192.168.86.237)
