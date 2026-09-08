# Adding a new Podman service behind Caddy

This repo uses **Caddy in `network_mode: host`** (`compose/tls-proxy`) so TLS terminates on the Linux host. Each site block listens on a **host TCP port** (for example `:8444`) and `reverse_proxy`s to a **backend** bound on the **host-internal address**, written in the Caddyfile as `{env.HOST_INTERNAL_IP}` (Caddy has no shell-style `${VAR}` substitution) and passed into the Caddy container by `compose/tls-proxy/compose.yaml` (other compose stacks publish ports to the host).

> **Publish on `${HOST_INTERNAL_IP}`, never a hardcoded address.** Under the `p-open-east-west` principle ([architecture/model.yaml](../architecture/model.yaml)), a published endpoint is reachable by every other container on the host with no shared-network setup. **The value is per-host** — `127.0.0.1` on beeblebox (native Linux + pasta `--map-host-loopback`), `10.255.255.254` on WSL2 — and neither is reachable from the home LAN or the tailnet, unlike `0.0.0.0`, which would publish to both. A port you do not publish stays private. See [NETWORK-CONFIG.md](NETWORK-CONFIG.md#container-to-container-traffic-east-west).

Use this checklist so the service is reachable from **other containers on the same host** and from **other PCs on your home LAN** (including through **WSL2 + Podman on Windows** if that is your setup).

### Automated scaffold (recommended)

```bash
./scripts/add-service.sh myapp --port 8099 --image docker.io/library/nginx:alpine
./scripts/sudo/bootstrap-host.sh   # installs new systemd/user/localserver-myapp.service if not done yet
./scripts/deploy-stack.sh myapp
```

Then add a Caddy `:<https-port> { ... reverse_proxy {env.HOST_INTERNAL_IP}:8090 }` block in `compose/tls-proxy/Caddyfile` and run `./scripts/deploy-stack.sh tls-proxy`.

- **Full ordered deploy** (everything in [compose/stack-order](../compose/stack-order)): `./scripts/deploy.sh`
- **One or more stacks only**: `./scripts/deploy-stack.sh <name> [<name> ...]`
- **Boot orchestration**: stacks listed in `compose/stack-order`; systemd units `systemd/user/localserver-*.service` call [scripts/start-stack.sh](../scripts/start-stack.sh).

---

## 1. Choose ports and names

- **Backend port** — the port your app listens on inside its container (for example `3000`).
- **Published host port** — map the container to the host with `ports: ["${HOST_INTERNAL_IP}:3000:3000"]`. That reaches Caddy and every other container, and nothing outside the host. Use `"0.0.0.0:3000:3000"` only when you deliberately want the raw port on the LAN.
- **HTTPS front door** — pick a **new, unused** host port for Caddy (for example `8455`). That is what browsers and other machines use as `https://<hostname>:8455`.

Avoid colliding with existing stacks (see [README](../README.md) “Stacks” and [tests/check-ports.sh](../tests/check-ports.sh)).

---

## 2. Add a Compose stack

1. Create `compose/<service-name>/compose.yaml` (same layout as `compose/hello-world` or `compose/n8n`).
2. Set `image`, `volumes`, `environment`, `restart`, and **`ports`** so the app is reachable at `${HOST_INTERNAL_IP}:<backend-host-port>`. Leave a port unpublished (a database, say) and it stays private to its own stack.
3. If the app must know its public URL (like n8n’s `N8N_EDITOR_BASE_URL`), set env vars to `https://<hostname>:<caddy-port>` using your LAN hostname or IP.

Bring it up once to verify:

```bash
cd compose/<service-name> && podman-compose up -d
curl -sS -o /dev/null -w "%{http_code}" "http://${HOST_INTERNAL_IP}:<backend-host-port>/"   # source ../../.env first
```

---

## 3. Register the stack for `./scripts/deploy.sh`

Add the stack name to [compose/stack-order](../compose/stack-order) (one name per line), **before** `tls-proxy` if the app should come up before the proxy in a full deploy. `add-service.sh` does this automatically.

Redeploy everything in order:

```bash
./scripts/deploy.sh
```

Or only specific stacks:

```bash
./scripts/deploy-stack.sh myapp tls-proxy
```

---

## 4. Optional: systemd user unit

`add-service.sh` writes `systemd/user/localserver-<service-name>.service` from [systemd/templates/localserver-stack.service.in](../systemd/templates/localserver-stack.service.in). [scripts/sudo/bootstrap-host.sh](../scripts/sudo/bootstrap-host.sh) installs every `localserver-*.service` into `~/.config/systemd/user/`.

---

## 5. Expose the service in Caddy

Edit [compose/tls-proxy/Caddyfile](../compose/tls-proxy/Caddyfile) and add a **new site block** (tabs are fine):

```caddyfile
:8455 {
	bind 0.0.0.0
	tls /certs/server.pem /certs/server-key.pem
	reverse_proxy {env.HOST_INTERNAL_IP}:<backend-host-port>
}
```

- **`bind 0.0.0.0`** — listen on all IPv4 interfaces on the host (good for LAN access from Linux-native Podman).
- **`reverse_proxy`** target must match where the backend is actually listening on the host.

Reload Caddy:

```bash
cd compose/tls-proxy && podman compose up -d && podman compose restart
# or: podman exec <caddy-container> caddy reload --config /etc/caddy/Caddyfile
```

> **`caddy reload` alone is not enough after a deploy.** The Caddyfile is bind-mounted as a
> single file, and rsync (and most editors) replace a file by writing a temp copy and
> renaming it — the running container stays bound to the old inode, so a reload re-reads the
> *previous* config and still reports success. `scripts/start-stack.sh` therefore
> force-recreates `tls-proxy` on every `up`. If you reload by hand, confirm the change
> actually landed: `podman exec <caddy-container> grep <your-new-port> /etc/caddy/Caddyfile`.

On **WSL2**, if published ports only show up on `[::1]`, LAN access still needs the Windows steps in section 7.

---

## 6. TLS certificates and trust

Caddy uses `certs/server.pem` from [scripts/setup-certs.sh](../scripts/setup-certs.sh). If you will browse using a **new hostname**, add it (and the LAN IP if needed) when (re)generating certs so clients do not see name mismatches. See [docs/tls.md](tls.md).

Every client (LAN PC, phone, browser on Windows next to WSL) must **trust `certs/ca.pem`** unless you move to a public CA later.

---

## 7. Home LAN and WSL2 + Windows

**Linux firewall** — if you use `ufw` on the server, allow the new **Caddy** TCP port (and the raw HTTP port only if you exposed it LAN-wide on `0.0.0.0`).

**DNS / hosts** — other PCs need a name or IP that reaches the machine running Podman (for example `192.168.86.50 <hostname>` in hosts, or your router DNS). See [docs/NETWORK-CONFIG.md](NETWORK-CONFIG.md).

**Windows + WSL2 + Podman** — when listeners are only on IPv6 loopback from Windows’ point of view, run [scripts/setup-windows-podman-lan-ports.ps1](../scripts/setup-windows-podman-lan-ports.ps1) as Administrator after you change the Caddyfile (or rely on a scheduled task). That script reads **Caddy listener ports** from the Caddyfile and merges [compose/windows-lan-extra-ports.txt](../compose/windows-lan-extra-ports.txt) for ports that are **not** declared as `:PORT {` sites (for example plain **8080** for nginx).

Background: [WSL2 Podman / IPv6 localhost](NETWORK-CONFIG.md#wsl2-podman-ports-bound-to-ipv6-localhost-only).

---

## 8. Reachability from **other Podman containers** on the same host

`127.0.0.1` inside **container A** is **not** the host — which is exactly why services publish on `${HOST_INTERNAL_IP}` rather than loopback. Once a service does, any container reaches it with **no network configuration at all**:

```
http://host.containers.internal:<backend-host-port>/
```

Podman injects `host.containers.internal` into every container automatically, and it resolves to the host-internal address. `host.docker.internal` works too where a stack declares `extra_hosts: - "host.docker.internal:host-gateway"`.

Use plain HTTP and the backend port directly. **Do not route east-west traffic through Caddy** — the `:844x` sites serve the private CA, so every consumer container would need `NODE_EXTRA_CA_CERTS` or an equivalent, and the cert's SANs do not cover container-visible hostnames. Caddy is for north-south traffic (browsers, external callers), not for one app calling another.

**A non-HTTP service gets no Caddy site at all.** `compose/gqldb` is the worked example: the graph
database speaks raw gRPC (HTTP/2 with its own session-id metadata auth), so there is nothing for a
`reverse_proxy` to usefully terminate, and its only consumer is the console container beside it.
Two consequences worth copying:

- `scripts/lib/post-deploy-caddy.sh` reads the **first** `ports:` entry in `compose.yaml` to find
  the stack's front door. A stack whose first published port has no Caddy site is skipped with
  *"No Caddy site for &lt;stack&gt;; skip verify"* — correct here, since a gRPC port is not
  curl-able. If such a stack *also* has a web UI, declare the **web service first** so the deploy
  still verifies something. `compose/gqldb/compose.yaml` does exactly that, with a comment saying
  why the order must not be tidied.
- Two services in one compose file share a pod (`pod_<stack>`), but podman-compose creates it with
  `SharedNamespaces: []` and no infra container — a **grouping, not a shared network namespace**.
  They reach each other by service DNS name (`gqldb:60061`), never on `127.0.0.1`.

Verify from any running container:

```bash
podman exec <some-container> wget -qO- http://host.containers.internal:<backend-host-port>/
```

**Authenticate the endpoint.** Under `p-open-east-west` every container can reach every published port, so network position is not authentication — see `gap-flat-east-west` in [architecture/model.yaml](../architecture/model.yaml) for the accepted residual risk. If a service must not be callable by other workloads, do not publish its port; keep it on its stack's own compose network (as `litellm`'s Postgres does).

---

## 9. Tailnet path routing (Tailscale)

Beyond the LAN Caddy ports above, the server exposes services over Tailscale by **path name instead of port number**, on one of two tiers — pick based on whether the service is safe to expose to the public internet:

- **Public, low-risk services** (no real data or credentials, e.g. `hello-world`, `tic-tac-toe`): mount directly on the existing public Funnel, no Caddy involved —
  ```bash
  ssh <server> tailscale serve --bg --set-path=/<name> http://127.0.0.1:<backend-port>   # the server's HOST_INTERNAL_IP
  ```
  This strips the `/<name>` prefix before forwarding, so the backend sees plain `/...` paths. That's correct for stateless/simple apps, but if the frontend makes API calls with **absolute root paths** (`fetch("/api/...")`), fix it to use `location.pathname`-relative paths first — see `compose/tic-tac-toe/templates/index.html`'s `BASE` constant for the pattern. Confirm with `tailscale funnel status` that the existing root mount (n8n) is untouched before and after.

- **Sensitive/admin services** (system access, credentials, e.g. Cockpit, LiteLLM): add a `handle_path /<name>/*` (prefix-stripped) or `handle /<name>/*` (prefix-preserved — use this if the backend has its own hardcoded path convention, like Cockpit's `/cockpit/...` asset scheme) block to the **`:8090` tailnet-only path router** in `compose/tls-proxy/Caddyfile`, then redeploy `tls-proxy`. No new Tailscale mount needed — `:8090` is already mounted tailnet-only via `tailscale serve --bg --https=8090 http://127.0.0.1:8090`.

Full rationale, the exposure-tiering decision, and why `--set-path` stripping is safe for some backends but broke n8n's webhook routing: see [docs/NETWORK-CONFIG.md](NETWORK-CONFIG.md#tailnet-path-routing).

---

## 10. Record the service in the architecture model

**This step is enforced — `./scripts/deploy.sh` refuses to run against a non-conformant model.**

Add the service to [`architecture/model.yaml`](../architecture/model.yaml) rather than listing it in
prose. Nothing about a new service belongs in README.md or NETWORK-CONFIG.md; those describe the
platform's mechanisms, and the model holds which services use them.

- An `ApplicationComponent` (`ac-<name>`): `stack`, `image`, `lifecycle`, `routing`
  (`strip` | `no-strip` | `not-path-mounted`), and — if `image` is `locally built` — `source`, being
  the repo that owns the app (or `in-repo`). The `source` attribute is what keeps this repo's docs
  neutral to the projects that depend on it; the validator requires it.
- An `ApplicationService` (`as-<name>`) per reachable endpoint, with an `exposed_via`
  relationship to exactly one exposure tier.

Check it before committing (the `.githooks/pre-commit` hook does this for you):

```bash
python3 scripts/arch-validate.py
```

Application-specific deployment notes — OAuth metadata paths, edge config, anything true only of
this one app — go in `compose/<service-name>/README.md`, not in the platform docs.

---

## 11. Verify end-to-end

On the server:

```bash
./scripts/check-tls.sh
./tests/check-ports.sh   # extend this script if you want automated checks for new ports
```

From another LAN PC: open `https://<hostname>:<caddy-port>` (after trusting the CA).

From another container (example):

```bash
podman run --rm --add-host=<hostname>:host-gateway curlimages/curl \
  -sk https://<hostname>:<caddy-port>/
```

(`-k` skips verify only for a quick test; install the CA for real use.)

---

## Quick reference

| Goal | What to touch |
|------|----------------|
| Run the app | `compose/<name>/compose.yaml`, `podman-compose up -d` |
| HTTPS URL on LAN | `compose/tls-proxy/Caddyfile` (`:PORT { ... reverse_proxy {env.HOST_INTERNAL_IP}:... }`) |
| Deploy all (ordered) | `compose/stack-order` + `./scripts/deploy.sh` |
| Deploy one stack | `./scripts/deploy-stack.sh <name>` |
| Scaffold + unit file | `./scripts/add-service.sh <name>` |
| New hostname in cert | `scripts/setup-certs.sh` + restart tls-proxy |
| WSL2 / Windows LAN | `scripts/setup-windows-podman-lan-ports.ps1` + `compose/windows-lan-extra-ports.txt` if needed |
| Container → another container | `http://host.containers.internal:<backend-port>` — no network config, no TLS |
| Tailnet URL, public/low-risk | `tailscale serve --set-path=/<name> http://127.0.0.1:<port>` (beeblebox) |
| Tailnet URL, sensitive/admin | `handle`/`handle_path /<name>/*` block in the `:8090` router (`compose/tls-proxy/Caddyfile`) |
