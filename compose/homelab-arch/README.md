# homelab-arch — Homelab Architecture Manager

One container: FastAPI serving the browser app, its API (`/api`) and an MCP endpoint (`/mcp`)
for AI agents. Metadata store: the `homelab_arch` graph in `compose/gqldb`. The application
lives in its own repository (`~/dev/homelab-arch`); this stack only builds and runs it.

| | |
|---|---|
| People (designed route) | `https://beeblebox.taile98462.ts.net:8099/` — tailnet only, password (`basic_auth`) |
| Agents on the tailnet | `https://beeblebox.taile98462.ts.net:8105/mcp` and `/api/agent/*` — bearer `AGENT_API_TOKEN` |
| Containers on this host | `http://host.containers.internal:8104` — `/mcp`, `/api/agent/*` with the agent token; read API open |
| LAN | none, on purpose |
| Data | volume `homelab-arch_proposals-data` (`/data/proposals.db`, SQLite: proposal queue + audit log) |
| Graph login | scoped user `hla_app` with role `hla_rw` = `ALL` on graph `homelab_arch` only |

## Deploying a new version

On the workstation (the app repo's `main` must contain the commit you want):

```bash
compose/homelab-arch/sync-app.sh main          # vendors `git archive main` into ./app (git-ignored)
./scripts/deploy-service.sh prod beeblebox homelab-arch
```

`build.sh` builds on the server from `./app` and keeps the image it replaces as
`localhost/homelab-arch_app:previous`. `app/SOURCE_COMMIT` records the commit.

**Every `envs/<env>.env` used with a full `./scripts/deploy.sh` needs the variables below, and
`./app` must be vendored first**, or the deploy stops at this stack (`set -e`) and skips the stacks
after it (only `tls-proxy`, which is why this stack sits directly before it in `stack-order`).

## Variables (`envs/<env>.env`; values never in git)

| Name | Used by | What |
|---|---|---|
| `HLA_GQLDB_PASSWORD` | app | password of the scoped GQLDB user `hla_app` |
| `HLA_APPROVER_TOKEN` | app, tls-proxy | ≥ 32 chars, ≥ 16 distinct; Caddy adds it as `X-HLA-Approver` on `:8099` after the password check |
| `AGENT_API_TOKEN` | app | ≥ 32 chars, ≥ 16 distinct, different from the approver token; give it only to agents |
| `HLA_BASIC_AUTH_HASH` | tls-proxy | `basic` mode only: **base64** of `caddy hash-password` output (no `$` in `.env`); unset → tls-proxy's lock-out default |
| `HLA_HUMAN_AUTH` | app, tls-proxy | `basic` (default) or `tailnet-trust` (what production runs: the owner's proof-of-concept decision); anything else means `basic` |

Unusable tokens (too short, too few distinct characters, or the two equal) silently disable
approving / agent access: those endpoints answer 503. The compose also sets
`HLA_ALLOW_GRAPH_WRITES=homelab_arch` (explicit opt-in to graph writes); remove that line and
the deployed app becomes read-only ("writes switched off").

Generate them with the commands in the app repo's `docs/deployment.md` ("B1"). The
`tailnet-trust` setting removes the `:8099` password: any tailnet device AND any process on this
host (tls-proxy uses host networking, so its loopback sites are reachable from every container),
an AI agent included, could then approve its own proposals. The app's review screen says so
while it is set. After changing `HLA_HUMAN_AUTH`, redeploy BOTH `homelab-arch` and `tls-proxy`,
so the app's warning and Caddy's behaviour agree.

Known limitation (D7): podman-compose passes these secrets to `podman create` as `-e NAME=value`
arguments, so they are visible in the host's process list (`ps`) for the moment the container is
created, and in `podman inspect`. Only local users of the server can see them; there is no
`env_file`/secret-store alternative in this podman-compose version. Treat the server's local
accounts as inside the trust boundary and rotate the tokens if that ever stops being true.

## Ontology sync

The container never syncs at start-up (`HLA_SKIP_SYNC=1`). After an ontology change, and only
with the owner's say-so:

```bash
podman exec homelab-arch_app_1 python -m homelab_arch sync --check   # read-only
podman exec homelab-arch_app_1 python -m homelab_arch sync           # WRITES ont_* nodes
```

## Backup and restore

`backup.sh <dir>` (called by `scripts/backup.sh`) writes `<dir>/homelab-arch-proposals.db`: an
online SQLite backup made inside the container, integrity-checked twice. A failure exits
non-zero (`set -e`), so the calling backup reports it instead of silently skipping. Restore
(app stopped):

```bash
podman stop homelab-arch_app_1
podman cp homelab-arch-proposals.db homelab-arch_app_1:/data/proposals.db
podman run --rm --user 0 -v homelab-arch_proposals-data:/data --entrypoint chown \
  localhost/homelab-arch_app:latest 10001:10001 /data/proposals.db
podman start homelab-arch_app_1
```
Start-up then reconciles any proposal that was mid-apply in the backup.

## Rollback

Note `app/SOURCE_COMMIT` before every deploy. To go back, vendor the previous commit and deploy
again (deterministic, whatever `start-stack.sh` does with images):

```bash
compose/homelab-arch/sync-app.sh <previous-commit>
./scripts/deploy-service.sh prod beeblebox homelab-arch
```

Faster, on the server, when nothing but the image changed: the image the last build replaced is
`localhost/homelab-arch_app:previous`; `podman tag` it as `:latest` and recreate the container
with `podman-compose up -d --force-recreate --no-build` in this directory (with `.env` exported).
A database restored from an older backup is fine with either: start-up reconciles it.
