# gqldb — Ultipa GQLDB + GQLDB Manager

Two containers in one pod (`pod_gqldb`): a GQL graph database speaking raw gRPC, and the
web console that manages it.

| | |
|---|---|
| Console (designed route) | `https://beeblebox.taile98462.ts.net:8098/` — tailnet only, linked from the `:8090` router index |
| Console (break-glass) | `https://<host>:8450` — LAN, private CA |
| Database | `${HOST_INTERNAL_IP}:60061`, gRPC only. No Caddy site, no LAN or tailnet exposure |
| Licence | Community Edition — 1M nodes, 1M edges, **2 user graphs**, 2 cores |

`__system__` does **not** count toward the graph limit — measured, not inferred: with
`default` plus one more graph the server refuses a third with
`[6012] database limit exceeded: current 2, limit 2`. So there is exactly one free slot
beside `default`.

## Connecting the console to the database: the host is `gqldb`

The console's connection form suggests `localhost` (`hostPlaceholder: "localhost"` in its bundle).
**That cannot work here, and neither can `beeblebox` or the tailnet name.** Measured:

| Host entered | Result |
|---|---|
| `gqldb` | works — compose service DNS |
| `host.containers.internal` | works — pasta maps it to the host's loopback publish |
| `localhost` / `127.0.0.1` | *Cannot reach server* in ~3ms |
| `beeblebox` / `beeblebox.taile98462.ts.net` | *Cannot reach server* in ~3ms |

Two independent reasons, both deliberate:

- **`localhost` is the console's own container.** The stack shares a *pod*, but podman-compose
  creates it with `SharedNamespaces: []` and no infra container — a grouping, not a shared network
  namespace. The console's netns has no listener on 60061 at all.
- **`beeblebox` and the tailnet name are the host's LAN/tailnet addresses**, and the database is
  published *only* on `127.0.0.1:60061`. Nothing is listening on those interfaces, on purpose:
  the database has no LAN or tailnet exposure.

The failure is fast (~3ms) rather than a timeout, because the connection is refused outright — a
useful tell that it is an address problem and not a credentials or TLS one.

A connection named **gqldb** pointing at `gqldb:60061` is already saved in the console. If it is
ever deleted, re-create it with that host, not with the placeholder.

## Reaching the database from another machine (Transporter, drivers, grpcurl)

The database is published on `127.0.0.1:60061` only — no LAN, no tailnet. That is deliberate, so
remote tools reach it through an **SSH tunnel over Tailscale** rather than by widening the exposure:

```bash
# on the client machine (Tailscale up, SSH access to beeblebox)
ssh -N -L 60061:127.0.0.1:60061 daradoom@beeblebox
```

Then point the tool at `127.0.0.1:60061` as if the database were local.

Verified end to end: through such a tunnel, `gqldb.SessionService/Login` returns a session and
`gqldb-grpc 6.2.131 (core v1.1.412) [Community Edition]`.

**Ultipa Transporter** is the right tool for bulk load/extract and it is GQLDB-native — its two
binaries are literally `gqldb-importer` and `gqldb-exporter` (docs: Ultipa Tools -> Ultipa
Transporter, v6.2). Download needs an Ultipa sign-in; no installation. Generate a starter config
with `./gqldb-importer -sample csv`, then run `./gqldb-importer -c config.yaml`. The connection
block for this deployment, through the tunnel:

```yaml
mode: csv
server:
  host:                        # a LIST of host:port entries, not separate host/port fields
    - "127.0.0.1:60061"        # the tunnel's local end
  username: "admin"
  password: "${GQLDB_PASSWORD}"   # env var interpolation is supported - keep it out of the file
  graph: "default"
  timeout: 60
  # tls.enabled stays false: the wire is plaintext gRPC, secured by SSH/Tailscale, not by TLS.
settings:
  import_mode: upsert          # default is overwrite, which replaces on duplicate _id
```

`-host`, `-username`, `-password` and `-graph` can also be passed on the command line to override
the file. Mind the Community Edition ceiling: if the importer auto-creates a graph it consumes one
of the two user-graph slots.

Two things that bite:

- **The local port must be free on the client.** The dev workstation runs its own `ultipa-gqldb`
  on 60061; use `-L 60062:127.0.0.1:60061` there and point the tool at 60062.
- **Reflection is authenticated on this server**, so `grpcurl` needs `-proto gqldb.proto` (vendored
  in this directory) even through the tunnel — it cannot discover methods on its own.

If a persistent, tunnel-free route is ever wanted, the tailnet options are
`tailscale serve --bg --tcp 60061 tcp://127.0.0.1:60061` (no compose change, no boot race) or a
second `ports:` entry on the Tailscale IP (native, but reintroduces the `tailscale0` cold-boot
race). Both make the database reachable by every tailnet device with RBAC as the only guard, which
is why neither is the default.

Ultipa's Download Center also lists a **Backup and Restore** utility. This stack does not use it —
backups go through the server's own `BACKUP DATABASE`, see docs/BACKUP.md — but it is worth knowing
it exists before writing anything custom.

## Version pins that nothing checks for you

`scripts/check-updates.py` reports the *base* images (`alpine`, `node`, `grpcurl`), but it
cannot see either of the things this stack actually pins, because neither comes from a
container registry:

| Artifact | Pin | Where |
|---|---|---|
| `ultipa-gqldb` server binary | `6.2.131`, sha256 `effc0f30…39da` | `Dockerfile.gqldb` ARGs |
| GQLDB Manager | `1.0.99` `.deb` | `manager.deb.sha256` (the `.deb` itself is gitignored) |

Check the server by hand: `curl -s https://download.ultipa.com/gqldb/VERSION`, then take the
new hash from `https://download.ultipa.com/gqldb/v<version>/checksums.sha256` and bump
`GQLDB_VERSION` and `GQLDB_SHA256` **together**. `build.sh` fails if the hash in the
Dockerfile is edited away from the one that was verified.

The manager has no upstream to check: its GitHub repo returns 404 and there is no apt
source, so the `.deb` in this directory is the only copy. Keep one somewhere durable.

## Why the console is on its own port, not the :8090 path router

The router mounts services under a path (`/tictactoe`, `/weather`). This one cannot be: its built
client requests an absolute `/assets/index-*.js`, and the server exposes no base-path setting to
move the app under a prefix. `handle_path` would serve the HTML then 404 the bundle at the router
root; `handle` would pass a prefix the app cannot interpret. So it is root-mounted on `:8098` and
the router's index page links to it — the escape hatch `docs/NETWORK-CONFIG.md` prescribes.

The Tailscale mount is host state, not repo state; recreate it with:

```bash
tailscale serve --bg --https=8098 http://127.0.0.1:8098
```

## The console image is unpacked, not installed

The `.deb` is a desktop package, but the app inside is a workspace of `server` + `client` +
`electron` — the server is plain Express serving a built React client, and Electron is only a
shell. So the image runs `node server/dist/index.js`: no X11, no Xvfb.

Getting the code out needs `extract-asar.js` rather than `npx @electron/asar extract`. The official
tool also copies entries the archive flags as *unpacked*, reading them from the sibling
`app.asar.unpacked/` tree — and electron-builder pruned the non-Linux platform binaries (koffi's
`win32_arm64/koffi.exp` and `.lib`) from disk while leaving them in the archive index. The official
extractor therefore dies with `ENOENT` on files Electron would never open on Linux.
`extract-asar.js` skips unpacked entries and lets the `cp -a` overlay supply them, which is exactly
how Electron resolves them at runtime. It also keeps npm off the build path.

The native modules are **glibc** (`GLIBC_2.34+`), which is why the base is `node:22-bookworm-slim`
and not Alpine. `build.sh` `require()`s `ultipagqldb.node` to prove both the libc match and that
the overlay actually happened.

## The proto is vendored because reflection is authenticated

`gqldb.proto` sits in this directory and is baked into the image. That is not belt-and-braces:
**gRPC reflection on this server is behind the auth interceptor**, so `grpcurl` cannot resolve any
method without a session — including `SessionService/Login`, the very call needed to get one.
Cold, every request fails with `Unauthenticated: failed to query for service descriptor`.

With `-proto gqldb.proto`, `Login` works unauthenticated (as it must) and returns a `sessionId`
that subsequent calls carry as a `session-id` metadata header. `gqldb.Health/Check` is behind the
interceptor too, which is why `healthcheck.sh` logs in before probing it.

Keep the proto in step with `GQLDB_VERSION`. It comes from the vendor's own npm package
(`@ultipa-graph/ultipa-driver`, aliased `gqldb-nodejs`), whose copy also ships inside the manager
`.deb` at `node_modules/gqldb-nodejs/dist/proto/gqldb.proto`.

## Why the database has no Caddy site

It is HTTP/2 with bespoke `session-id` metadata auth. Proxying it through Caddy would
terminate nothing useful, would need `h2c` transport, and would put the private CA in the
path of a client that is not a browser. `docs/ADD-SERVICE.md` §8 keeps east-west traffic off
Caddy regardless. The console reaches it over the compose network instead.

**`pod_gqldb` is a grouping, not a shared network namespace** — podman-compose creates the
pod with `SharedNamespaces: []` and no infra container. So the console connects to
`gqldb:60061` by service DNS. `127.0.0.1:60061` from inside the console container will not
work, and is not supposed to.

## Secrets

All four live in `envs/<env>.env`. Every one of them overrides an app default that is unsafe
for a shared service — see `.env.example` for what each default is.

`scripts/start-stack.sh` force-recreates this stack on every deploy, because the console
reads these at startup and a plain `up` would leave an existing container on the old values.

### Rotating `MANAGER_ENCRYPTION_KEY`

This key encrypts the connection passwords the console stores, including this database's own
admin password. **Rotating it makes existing saved connections undecryptable** — the app
raises *"Connection credentials were encrypted with a different key. Please delete and
re-create this connection."* That is the recovery: delete the connection in the console and
add it again. There is no way to recover the old value from the new key.

### Rotating the database admin password

`GQLDB_RBAC_ADMIN_PASSWORD` is documented upstream as being for initial setup. If changing it
in `.env` does not take effect on an existing store, reset it offline with the stack down:

```
podman run --rm -v gqldb_gqldb-data:/data localhost/gqldb_gqldb -db /data -reset-admin-pass '<new>'
```

## Backups

The database is dumped logically — `BACKUP DATABASE` has the server write and verify its own
archive while it keeps serving, so the LSM directory is never file-copied. The console's own
embedded store has no dump command, so it is stopped for a cold copy instead. See
`docs/BACKUP.md` for the restore drill; a backup that has never been restored is not a backup.
