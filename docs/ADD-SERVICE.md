# Adding a new Podman service behind Caddy

This repo uses **Caddy in `network_mode: host`** (`compose/tls-proxy`) so TLS terminates on the Linux host. Each site block listens on a **host TCP port** (for example `:8444`) and `reverse_proxy`s to a **backend** that is usually bound on **`127.0.0.1:<port>`** on the same host (other compose stacks publish ports to the host).

Use this checklist so the service is reachable from **other containers on the same host** and from **other PCs on your home LAN** (including through **WSL2 + Podman on Windows** if that is your setup).

---

## 1. Choose ports and names

- **Backend port** — the port your app listens on inside its container (for example `3000`).
- **Published host port** — map the container to the host with `ports: ["3000:3000"]` (or `"127.0.0.1:3000:3000"` if you only want loopback; for Caddy on the same host, `127.0.0.1` is enough and slightly tighter).
- **HTTPS front door** — pick a **new, unused** host port for Caddy (for example `8455`). That is what browsers and other machines use as `https://darragh-pc:8455`.

Avoid colliding with existing stacks (see [README](../README.md) “Stacks” and [tests/check-ports.sh](../tests/check-ports.sh)).

---

## 2. Add a Compose stack

1. Create `compose/<service-name>/compose.yaml` (same layout as `compose/hello-world` or `compose/n8n`).
2. Set `image`, `volumes`, `environment`, `restart`, and **`ports`** so the app is reachable on the host at `127.0.0.1:<backend-host-port>` (or `0.0.0.0:<port>` if you prefer).
3. If the app must know its public URL (like n8n’s `N8N_EDITOR_BASE_URL`), set env vars to `https://<hostname>:<caddy-port>` using your LAN hostname (for example `darragh-pc`) or IP.

Bring it up once to verify:

```bash
cd compose/<service-name> && podman-compose up -d
curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:<backend-host-port>/
```

---

## 3. Register the stack in `deploy.sh` (optional but recommended)

In [scripts/deploy.sh](../scripts/deploy.sh), add `<service-name>` to the `for name in hello-world n8n tls-proxy` loop **before** `tls-proxy` if the new stack does not depend on certs, or in dependency order if it does.

Redeploy:

```bash
./scripts/deploy.sh --compose-only
```

---

## 4. Optional: systemd user unit

To match hello-world / n8n, copy [systemd/user/localserver-hello-world.service](../systemd/user/localserver-hello-world.service) to `systemd/user/localserver-<service-name>.service`, set `WorkingDirectory` to `__REPO_ROOT__/compose/<service-name>`, then extend the `units=(...)` array and the `for unit in` loop in `deploy.sh` → `setup_systemd()` so `deploy.sh` installs and enables the new unit.

---

## 5. Expose the service in Caddy

Edit [compose/tls-proxy/Caddyfile](../compose/tls-proxy/Caddyfile) and add a **new site block** (tabs are fine):

```caddyfile
:8455 {
	bind 0.0.0.0
	tls /certs/server.pem /certs/server-key.pem
	reverse_proxy 127.0.0.1:<backend-host-port>
}
```

- **`bind 0.0.0.0`** — listen on all IPv4 interfaces on the host (good for LAN access from Linux-native Podman).
- **`reverse_proxy`** target must match where the backend is actually listening on the host.

Reload Caddy:

```bash
cd compose/tls-proxy && podman compose up -d && podman compose restart
# or: podman exec <caddy-container> caddy reload --config /etc/caddy/Caddyfile
```

On **WSL2**, if published ports only show up on `[::1]`, LAN access still needs the Windows steps in section 7.

---

## 6. TLS certificates and trust

Caddy uses `certs/server.pem` from [scripts/setup-certs.sh](../scripts/setup-certs.sh). If you will browse using a **new hostname**, add it (and the LAN IP if needed) when (re)generating certs so clients do not see name mismatches. See [docs/tls.md](tls.md).

Every client (LAN PC, phone, browser on Windows next to WSL) must **trust `certs/ca.pem`** unless you move to a public CA later.

---

## 7. Home LAN and WSL2 + Windows

**Linux firewall** — if you use `ufw` on the server, allow the new **Caddy** TCP port (and the raw HTTP port only if you exposed it LAN-wide on `0.0.0.0`).

**DNS / hosts** — other PCs need a name or IP that reaches the machine running Podman (for example `192.168.86.237 darragh-pc` in hosts, or your router DNS). See [docs/NETWORK-CONFIG.md](NETWORK-CONFIG.md).

**Windows + WSL2 + Podman** — when listeners are only on IPv6 loopback from Windows’ point of view, run [scripts/setup-windows-podman-lan-ports.ps1](../scripts/setup-windows-podman-lan-ports.ps1) as Administrator after you change the Caddyfile (or rely on a scheduled task). That script reads **Caddy listener ports** from the Caddyfile and merges [compose/windows-lan-extra-ports.txt](../compose/windows-lan-extra-ports.txt) for ports that are **not** declared as `:PORT {` sites (for example plain **8080** for nginx).

Background: [WSL2 Podman / IPv6 localhost](NETWORK-CONFIG.md#wsl2-podman-ports-bound-to-ipv6-localhost-only).

---

## 8. Reachability from **other Podman containers** on the same host

`127.0.0.1` inside **container A** is **not** the host. To hit Caddy or a published port on the host:

1. **Prefer the host’s LAN IP or hostname** — for example `https://192.168.86.237:8455` or `https://darragh-pc:8455`, if the container can resolve `darragh-pc` (add `extra_hosts` if needed), and trust the CA or use tooling flags for dev.
2. **Podman / Compose** — you can add:
   - `extra_hosts: - "darragh-pc:host-gateway"`  
     (same idea as n8n’s [compose/n8n/compose.yaml](../compose/n8n/compose.yaml) `host-gateway` pattern), then use `https://darragh-pc:<caddy-port>` from the app.
3. **`host.containers.internal`** — on many Podman setups this resolves to the host; try `curl -k https://host.containers.internal:8455` from a throwaway container.

For **service-to-service without TLS** on a private user network, you can instead attach stacks to the same Podman network and call `http://other-service:port` by compose service name. That path bypasses Caddy; use it when you do not need the public HTTPS URL.

---

## 9. Verify end-to-end

On the server:

```bash
./scripts/check-tls.sh
./tests/check-ports.sh   # extend this script if you want automated checks for new ports
```

From another LAN PC: open `https://darragh-pc:<caddy-port>` (after trusting the CA).

From another container (example):

```bash
podman run --rm --add-host=darragh-pc:host-gateway curlimages/curl \
  -sk https://darragh-pc:<caddy-port>/
```

(`-k` skips verify only for a quick test; install the CA for real use.)

---

## Quick reference

| Goal | What to touch |
|------|----------------|
| Run the app | `compose/<name>/compose.yaml`, `podman-compose up -d` |
| HTTPS URL on LAN | `compose/tls-proxy/Caddyfile` (`:PORT { ... reverse_proxy 127.0.0.1:... }`) |
| Deploy with `./scripts/deploy.sh` | `scripts/deploy.sh` stack list (+ optional systemd unit) |
| New hostname in cert | `scripts/setup-certs.sh` + restart tls-proxy |
| WSL2 / Windows LAN | `scripts/setup-windows-podman-lan-ports.ps1` + `compose/windows-lan-extra-ports.txt` if needed |
| Container → Caddy | `host-gateway` / LAN IP / `host.containers.internal`, not `127.0.0.1` |
