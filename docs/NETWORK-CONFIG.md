# Network Configuration: Desktop as HTTPS Server

Configuration for exposing containerized HTTPS services from your desktop (WSL) to both **local devices** and **remote** (public internet), using `thelearningcto.com` and avoiding inbound exposure of your home network.

---

## Current State

| Component | Your Setup |
|-----------|------------|
| Desktop | WSL + Podman, network mirroring, Caddy TLS proxy |
| Laptop | WSL (same stack possible) |
| Network | Google Home Wi‑Fi → Verizon FIOS router (bridged) |
| Domain | thelearningcto.com (Route53, unused) |
| Certs | Self-signed CA (certs/ca.pem) — clients must trust |
| DNS | Hosts files only; no local DNS server |

---

## Architecture Overview

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    YOUR HOME LAN                        │
                    │  Google Home Wi-Fi (192.168.86.x / similar)              │
                    │                                                         │
                    │   ┌──────────────┐         ┌──────────────┐             │
                    │   │   Laptop     │         │   Desktop    │             │
                    │   │   (WSL)      │         │   (WSL)      │◄─── SERVER  │
                    │   └──────┬───────┘         └──────┬───────┘             │
                    │          │                        │                     │
                    │          │  hosts: darragh-pc     │                     │
                    │          │  → 192.168.86.237       │                     │
                    │          └────────────────────────┘                     │
                    │                     │                                   │
                    └─────────────────────┼───────────────────────────────────┘
                                          │
                    Verizon FIOS router   │
                    (bridge mode)         │
                                          ▼
                    ┌─────────────────────────────────────────────────────────┐
                    │                   INTERNET                              │
                    │                                                         │
                    │  Option A: Cloudflare Tunnel (outbound only, no ports)  │
                    │  Option B: Tailscale (mesh VPN, no ports)                │
                    │  Option C: WireGuard VPN (one UDP port)                 │
                    │  Option D: Port forward 443 (highest risk)               │
                    └─────────────────────────────────────────────────────────┘
                                          │
                    ┌─────────────────────┼───────────────────────────────────┐
                    │   Remote devices (phone, work laptop, etc.)             │
                    └─────────────────────┴───────────────────────────────────┘
```

---

## Recommended: Cloudflare Tunnel + Let's Encrypt (Safest for Remote)

This keeps **no inbound ports** to your home network. Desktop makes outbound connections to Cloudflare.

### How it works

1. Create a free Cloudflare account, add `thelearningcto.com` (use Cloudflare nameservers or CNAME to Route53).
2. Run `cloudflared` on the desktop; it connects outbound to Cloudflare.
3. Cloudflare terminates TLS at the edge; traffic to `*.thelearningcto.com` is proxied to your tunnel.
4. Get **trusted** Let's Encrypt certs via Route53 DNS-01 (no port 80/443 open).
5. Caddy serves HTTPS locally with real certs; Cloudflare only needed for *remote* access.

### Local access (unchanged)

- Hosts: `192.168.86.237 darragh-pc` (or `thelearningcto.com` if you prefer).
- Use `https://darragh-pc:8443` or `https://thelearningcto.com:8443` locally.
- Certificates will be valid (Let's Encrypt) — no CA trust needed on clients.

### Remote access

- `https://n8n.thelearningcto.com` → Cloudflare Tunnel → desktop:8444
- `https://hello.thelearningcto.com` → Cloudflare Tunnel → desktop:8443

### Optional: Cloudflare Access

Add Zero Trust policies: require email/SAML/OTP before reaching your services. Reduces exposure if tunnel credentials leak.

---

## Alternative: Tailscale (Simplest for Personal Use)

Tailscale creates a mesh VPN. Each device gets a Tailscale IP; no port forwarding or domain required for basic use.

### How it works

1. Install Tailscale on desktop, laptop, phone, etc.
2. All devices are on a private mesh (e.g. `100.x.x.x`).
3. Access desktop from anywhere: `https://100.x.x.x:8443` (replace with desktop’s Tailscale IP).
4. Use a Tailscale MagicDNS name (e.g. `desktop.tailnet-name.ts.net`) instead of IP.

### Pros

- No port forwarding, no dynamic DNS, no domain setup.
- End-to-end encrypted; no third-party proxy.

### Cons

- Tailscale must be installed on every client.
- Uses Tailscale’s coordination servers (can self-host headscale if desired).
- Not ideal for sharing with unauthenticated users.

### With your domain

You can use `thelearningcto.com` with Let's Encrypt for local + Tailscale for remote:

- Local: `https://darragh-pc:8443` or `https://thelearningcto.com:8443` (hosts + Let’s Encrypt).
- Remote: `https://desktop.your-tailnet.ts.net:8443` or Tailscale IP.

---

### Tailscale on WSL (Desktop as Server)

Since your services (Caddy, n8n, hello-world) run in WSL, install Tailscale **inside WSL** so remote traffic reaches them directly.

**Important:** Run Tailscale either in WSL *or* on Windows, not both. Nested Tailscale (WSL + Windows) causes packet issues. For a WSL-hosted server, use WSL only.

#### 1. Install in WSL

```bash
# In WSL (Ubuntu)
curl -fsSL https://tailscale.com/install.sh | sh
```

#### 2. Connect

```bash
sudo tailscale up
```

A browser auth URL appears; complete sign-in. Your WSL node joins your tailnet.

#### 3. Get your Tailscale IP / MagicDNS

```bash
tailscale ip -4
# e.g. 100.101.102.103

tailscale status
# Shows MagicDNS name, e.g. darragh-pc.tail12345.ts.net
```

#### 4. Remote access URLs

From any device with Tailscale installed:

| Service     | URL (replace with your Tailscale name or IP)     |
|------------|---------------------------------------------------|
| hello-world | `https://darragh-pc.tail12345.ts.net:8443` or `https://100.x.x.x:8443` |
| n8n        | `https://darragh-pc.tail12345.ts.net:8444` or `https://100.x.x.x:8444` |

#### 5. Auto-start (optional)

Tailscale does not auto-start in WSL by default. Add to `~/.bashrc`:

```bash
if ! pgrep -x tailscaled > /dev/null; then
  sudo tailscaled &
fi
```

Or run `sudo tailscale up` after each WSL restart.

#### 6. Accept routes (optional)

If you want remote devices to reach your LAN via the desktop:

```bash
sudo tailscale up --advertise-routes=192.168.86.0/24 --accept-routes
```

Otherwise omit; direct access to 8443/8444 is enough for your services.

---

### Tailscale overwriting resolv.conf

Tailscale injects its MagicDNS (100.100.100.100) into `/etc/resolv.conf`, which overwrites your local DNS (e.g. dnsmasq at 192.168.86.237). To keep your own DNS:

```bash
sudo tailscale up --accept-dns=false
```

This disables Tailscale's DNS management. Your `resolv.conf` stays under your control. Configure it to use 192.168.86.237 (local dnsmasq) or 1.1.1.1 / 8.8.8.8 (Route53 via public resolvers).

**Important:** If dnsmasq is running, stop it before editing resolv.conf: `sudo systemctl stop dnsmasq`. Update resolv.conf, then start it again: `sudo systemctl start dnsmasq`. This avoids conflicts while resolv.conf is being changed.

**Trade-off:** You lose Tailscale MagicDNS (e.g. `darragh-pc.tailnet.ts.net` won't resolve). Use the Tailscale IP (100.x.x.x) directly for remote access instead.

---

### "Endpoint not reachable" troubleshooting

When `tailscale status` shows a peer as unreachable, try these in order:

#### Option A: Use Tailscale on Windows instead of WSL (recommended)

Tailscale in WSL often hits Windows Firewall / MTU issues. The simpler setup:

1. **Uninstall Tailscale from WSL:** `sudo apt-get remove tailscale`
2. **Install Tailscale for Windows:** [tailscale.com/download](https://tailscale.com/download) → run the installer
3. **Connect** in the Windows app
4. **Port forward** Windows → WSL (you already have this):
   ```powershell
   # Run as Admin (once per WSL restart)
   .\scripts\setup-windows-port-forward.ps1
   ```

Remote devices connect to your **Windows** Tailscale IP (e.g. `https://100.x.x.x:8443`). Windows forwards to WSL.

#### Option B: Fix Tailscale in WSL

If you prefer Tailscale in WSL:

**1. Windows Firewall** – allow inbound on the WSL interface for Tailscale:

```powershell
# Run PowerShell as Administrator
New-NetFirewallRule -DisplayName "Tailscale WSL" -Direction Inbound -Protocol UDP -LocalPort 41641 -Action Allow -InterfaceAlias "vEthernet (WSL)"
```

If the WSL interface has a different name, list them: `Get-NetAdapter`.

**2. MTU** – WSL2's default MTU can break Tailscale. In WSL, try:

```bash
# Check current MTU
ip link show eth0

# Lower Tailscale MTU (run after tailscale up)
sudo ip link set tailscale0 mtu 1280
```

**3. DERP relay** – If direct connection fails, Tailscale uses DERP. Check with `tailscale status`; "relay" means it's working via DERP (slower but functional). "Unreachable" means no path at all.

**4. Verify Tailscale is listening:**

```bash
ss -ulnp | grep tailscale
# Should show UDP 41641
```

---

## Alternative: WireGuard VPN

Run WireGuard on the desktop. Remote clients connect to a single UDP port (e.g. 51820); once connected, they see your LAN.

### How it works

1. Install WireGuard on desktop.
2. Forward UDP 51820 on Verizon router → desktop.
3. Configure peers (laptop, phone).
4. Remote users connect to VPN, then use `https://192.168.86.237:8443` or `https://darragh-pc:8443` (via hosts).

### Pros

- Single port, simple firewall rules.
- Full control; no third-party proxy.
- Good for a small set of trusted devices.

### Cons

- VPN client required on every remote device.
- One port is still open to the internet (lower risk than 443, but not zero).

---

## Option to Avoid: Direct Port Forward 443

Forwarding 443 from the internet to your desktop is possible but:

- Exposes your desktop and LAN to the internet.
- Requires dynamic DNS if Verizon gives you a dynamic IP.
- Increases attack surface; requires strong hardening (fail2ban, etc.).

Use only if you specifically need public, unauthenticated access and understand the risks.

---

## Certificate Strategy with thelearningcto.com

### Today (self-signed)

- SANs: `darragh-pc`, `localhost`, `127.0.0.1`, `192.168.86.237`.
- Clients must import `certs/ca.pem` (see [tls.md](tls.md)).

### With the domain (recommended)

Use Let's Encrypt with Route53 DNS-01:

1. Route53 hosted zone for `thelearningcto.com` (you have this).
2. ACME client (e.g. `certbot` or Caddy’s built-in) uses AWS credentials to create `_acme-challenge.thelearningcto.com` TXT.
3. Get a wildcard cert: `*.thelearningcto.com`, `thelearningcto.com`.
4. Caddy can obtain and renew automatically if you switch to its ACME provider.

**DNS-01 does not require** port 80 or 443 to be open; it works behind NAT.

### Caddy config with Let's Encrypt

```caddyfile
# Caddy ACME (Let's Encrypt) - requires DNS challenge plugin or separate cert
# Example: use certbot + Route53, then point Caddy at certs
thelearningcto.com:8443 {
  tls /certs/fullchain.pem /certs/privkey.pem
  reverse_proxy 127.0.0.1:8080
}
n8n.thelearningcto.com:8444 {
  tls /certs/fullchain.pem /certs/privkey.pem
  reverse_proxy 127.0.0.1:5678
}
```

Or use Caddy’s `tls` directive with a Route53 DNS challenge module if available.

---

## Troubleshooting: Laptop Cannot Reach darragh-pc

| Host | IP |
|------|-----|
| darragh-pc (desktop) | 192.168.86.237 |
| darragh-laptop | 192.168.86.236 |

**From darragh-laptop**, run:

```bash
./scripts/check-connectivity.sh 192.168.86.237
```

**From darragh-pc**, verify:

```bash
# Ports listening?
./tests/check-ports.sh

# Network & IPs
ip -br addr

# If ping fails from laptop: Windows Firewall may block ICMP
# In PowerShell (Admin): New-NetFirewallRule -DisplayName "ICMP" -Protocol ICMPv4 -IcmpType 8 -Action Allow
```

### WSL2 Podman: ports bound to IPv6 localhost only

Podman in WSL2 may bind published container ports to **IPv6 loopback only** (`[::1]`), so they are reachable from Windows on that host but **not** from other machines on the LAN until Windows accepts traffic and forwards **IPv4** to **IPv6 localhost**.

For **each** exposed port, run **Administrator PowerShell** on the Windows side:

**1. Windows Firewall (inbound TCP)**

```powershell
New-NetFirewallRule -DisplayName "<service> <port>" -Direction Inbound -Protocol TCP -LocalPort <port> -Action Allow
```

**2. Port proxy (IPv4 → IPv6 loopback)**

```powershell
netsh interface portproxy add v4tov6 listenport=<port> listenaddress=0.0.0.0 connectport=<port> connectaddress=::1
```

These rules **do not survive a reboot**. On **darragh-pc**, use [scripts/setup-windows-podman-lan-ports.ps1](../scripts/setup-windows-podman-lan-ports.ps1) (run as Administrator). It **reads listener ports** from `compose/tls-proxy/Caddyfile` (any line like `:8443 {` or `host:8443 {`) and merges [compose/windows-lan-extra-ports.txt](../compose/windows-lan-extra-ports.txt) for host-published ports that are not Caddy front doors (for example plain `8080` from hello-world). Re-run after editing Caddy or extras, or schedule **At startup** in Task Scheduler with **Run with highest privileges** (see script comment block). A small state file under `%LOCALAPPDATA%\localserver-config\` drops **removed** ports from `netsh` portproxy on the next run.

**Ports that commonly need this in this stack** (adjust names to taste):

| Port | Typical use |
|------|-------------|
| 8080 | hello-world (nginx) |
| 8444 | Caddy / n8n TLS |
| 9443 | Cockpit TLS |

**Diagnostics (Windows CMD or PowerShell)**

- `netstat -an | findstr <port>` — confirm the listening address. `[::1]:<port>` means IPv6 localhost only (LAN clients need the **v4tov6** proxy above). `0.0.0.0:<port>` means IPv4 is already listening broadly (no v4tov6 proxy needed for that symptom).
- `netsh interface portproxy show all` — list active portproxy rules.

**Note:** If you use **mirrored** WSL networking (`.wslconfig`: `networkingMode=mirrored`), see also [scripts/setup-windows-port-forward.ps1](../scripts/setup-windows-port-forward.ps1): it uses **v4tov4** to the WSL IP for 8443/8444 and deliberately **does not** add rules in mirrored mode. The **v4tov6 → ::1** pattern above is for the case where services are only listening on `[::1]` and you need IPv4 LAN access into that listener.

### Common causes

| Symptom | Cause | Fix |
|--------|-------|-----|
| Ping fails | Different subnet, or Windows Firewall | Same WiFi; allow ICMP in Windows Firewall |
| TCP 8443/8444 fails | Port forward not set, or Caddy down | `setup-windows-port-forward.ps1`; `./tests/check-ports.sh` |
| DNS (UDP 53) fails, TCP 53 OK | Windows Firewall blocks UDP | `New-NetFirewallRule -Protocol UDP -LocalPort 53 -Action Allow` |
| Connection refused | Traffic hits Windows, not WSL | `.wslconfig`: `networkingMode=mirrored` + `wsl --shutdown` |

---

## Hosts File Layout

| Device | Add to hosts |
|--------|--------------|
| Desktop (Windows) | `127.0.0.1 darragh-pc darragh-pc.thelearningcto.com thelearningcto.com` |
| Desktop (WSL) | `127.0.0.1 darragh-pc darragh-pc.thelearningcto.com thelearningcto.com` — use `sudo ./scripts/setup-wsl-hosts.sh` |
| Laptop / other WSL | `192.168.86.237 darragh-pc darragh-pc.thelearningcto.com thelearningcto.com` — use `sudo ./scripts/setup-wsl-hosts.sh 192.168.86.237` |
| Other LAN devices | `192.168.86.237 darragh-pc thelearningcto.com` |

Use the desktop’s **actual** LAN IP (e.g. DHCP reservation at `192.168.86.237`).

---

## DHCP Reservation (Recommended)

On the Google Home app (or router) set a static DHCP reservation for the desktop MAC → `192.168.86.237` so the IP is stable.

---

## Suggested Path

| Priority | Action |
|----------|--------|
| 1 | Add DHCP reservation for desktop |
| 2 | Add `thelearningcto.com` to cert SANs and hosts for local use |
| 3 | Issue Let's Encrypt cert via Route53 DNS-01 and switch Caddy to it |
| 4 | Deploy Cloudflare Tunnel for remote access (or Tailscale if you prefer) |
| 5 | Optional: Cloudflare Access for extra protection |

---

## Quick Reference: Local vs Remote

| Access | URL example | Mechanism |
|--------|-------------|-----------|
| Local (same machine) | `https://127.0.0.1:8443` | Caddy in WSL |
| Local (LAN) | `https://darragh-pc:8443` or `https://192.168.86.237:8443` | Hosts + Caddy |
| Remote | `https://n8n.thelearningcto.com` | Cloudflare Tunnel → Caddy |

---

## Security Checklist

- [ ] Change n8n default password (see [IMPROVEMENTS.md](IMPROVEMENTS.md))
- [ ] Set `N8N_ENCRYPTION_KEY` for n8n
- [ ] Use Let's Encrypt for trusted certs (no manual CA trust)
- [ ] Prefer Cloudflare Tunnel or Tailscale over port forwarding
- [ ] Optional: Cloudflare Access or Tailscale ACLs for access control
- [ ] Firewall: only allow 8443/8444 from LAN if not using tunnel for local-only
