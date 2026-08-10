# Project Improvements: Configuration & n8n Reliability

*Status as of 2026-08-08. Items below were written before several rounds of hardening; each now carries a status.*

## 1. Configuration Simplification

### 1.1 Single env file for host-specific values
**Status:** ✅ Resolved (partially by design change, not literally as proposed)
**Current:** `deploy.sh` auto-detects `N8N_HOST` via `$(hostname)` and derives `N8N_EDITOR_BASE_URL` from it if not set — no per-host edit needed for the common case. `.env`/`envs/<env>.env` still holds secrets (password, encryption key).
**Remaining:** No explicit `HOST`/`LAN_IP` vars as originally proposed; auto-detection covers most cases but doesn't help when LAN IP must be pinned (e.g. cert SANs) — that's handled separately via `DEPLOY_CERT_EXTRA_SANS`.

### 1.2 Consolidate compose file names
**Status:** ⚠️ Partial
**Current:** The `docker-compose.yaml` symlink was removed from `tls-proxy` (commit `967841f`) but still exists in `compose/n8n/`.
**Improvement:** Remove the remaining `compose/n8n/docker-compose.yaml` symlink or document why n8n keeps it.

### 1.3 Hardcoded hostname in deploy-to-server
**Status:** ✅ Mostly resolved
**Current:** `deploy-to-server.sh` no longer defaults to `darragh-pc` — target is a required positional arg, and "is this machine" detection is generic (hostname match, loopback, or LAN IP). `scripts/deploy-litellm.sh` still hardcodes `PROD_HOST="darragh-pc"` as its prod default.
**Remaining:** Generalize `deploy-litellm.sh`'s `PROD_HOST` the same way, or fold it into `deploy-service.sh`.

### 1.4 Cert setup: reduce prompts
**Status:** ✅ Resolved
**Current:** `setup-certs.sh` takes hostnames/IPs as positional args (no interactive prompt); `deploy-to-server.sh` auto-fills SANs (hostname, `.local`, first LAN IP, deploy target) when regenerating certs remotely.

---

## 2. n8n Reliability (Production-Ready)

### 2.1 Security: N8N_ENCRYPTION_KEY **[High]**
**Status:** ✅ Resolved (commit `e3ad8f5`)
**Current:** `N8N_ENCRYPTION_KEY` is required via env, no default; `.env.example` documents generation with `openssl rand -hex 32` and warns credentials become unrecoverable if lost.

### 2.2 Change default password **[High]**
**Status:** ✅ Resolved (commit `8d10266`)
**Current:** `N8N_BASIC_AUTH_PASSWORD` is required via env, no hardcoded `changeme` default; `deploy.sh` validates required n8n env vars before deploying (`validate_n8n_env_for_stacks`).

### 2.3 Database: Postgres for production **[Medium]**
**Status:** ✅ Resolved as optional overlay (commit `508a67d`)
**Current:** `compose/n8n/compose.postgres.yaml` is an overlay applied when `N8N_DATABASE=postgres`, with a healthcheck-gated Postgres service. SQLite remains the default.
**Remaining:** SQLite is still the default and isn't documented as "dev/single-user only" in the README — worth a one-line callout.

### 2.4 Image tag: avoid `latest` **[Medium]**
**Status:** ✅ Resolved (commit `455068a`)
**Current:** Pinned to `n8nio/n8n:2.19.5`.

### 2.5 EXECUTIONS_MODE for concurrency **[Low]**
**Status:** ⏳ Open
**Current:** Default `regular`, unchanged. Still low priority for a single-user/small setup.

### 2.6 Native Python task runner for Code node **[Low]**
**Status:** ⏳ Open
**Current:** Code node only has JS and Pyodide-sandboxed Python (no stdlib/third-party package access). Native Python (n8n 1.111.0+; deployed version 2.33.7 supports it) requires a separate `n8nio/runners` container.
**Remaining:** Add a `task-runners` service to `compose/n8n/compose.yaml` (`N8N_RUNNERS_MODE=external`, `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0`, `N8N_NATIVE_PYTHON_RUNNER=true` on the `n8n` service; shared `N8N_RUNNERS_AUTH_TOKEN` secret on both), plus explicit `N8N_RUNNERS_STDLIB_ALLOW`/`N8N_RUNNERS_EXTERNAL_ALLOW` import allowlists (everything is blocked by default). Note: switching to native Python is a breaking change for any existing Python Code nodes — it only exposes `_items`/`_item`, not the full set of n8n built-ins Pyodide mode supports.

---

## 3. Operational Reliability

### 3.1 Health checks in compose
**Status:** ✅ Resolved
**Current:** All stacks (hello-world, n8n, litellm, tic-tac-toe, tls-proxy) have healthchecks in their `compose.yaml`.

### 3.2 Caddy: cert reload on change
**Status:** ✅ Resolved (commit `ba48679`)
**Current:** `scripts/reload-tls-proxy-caddy.sh` reloads Caddy without a container restart; `deploy.sh` and `deploy-to-server.sh` call it automatically post-deploy via `scripts/lib/post-deploy-caddy.sh`.

### 3.3 Backup n8n data
**Status:** ⏳ Open
**Current:** No backup script exists yet. Still needed: `scripts/backup-n8n.sh` to tar the `n8n-data` volume (or dump SQLite/Postgres) to a timestamped file, plus a retention/off-site note.

### 3.4 Deploy order / dependencies
**Status:** ✅ Resolved
**Current:** `compose/stack-order` lists app stacks before `tls-proxy`. `scripts/lib/post-deploy-caddy.sh` polls each backend's health path before verifying it through Caddy (`wait_for_stack_backend`), and reloads Caddy after new stacks come up — avoids the 502-before-backend-ready race the original item flagged.

---

## 4. Testing & Validation

### 4.1 Add n8n-specific test
**Status:** ⏳ Open
**Current:** `post-deploy-caddy.sh` curls n8n's `/healthz` through Caddy as part of deploy verification, but there's still no standalone `tests/check-n8n.sh` or n8n check in `check-tls.sh` for use outside a deploy run.

### 4.2 Run tests in deploy
**Status:** ✅ Resolved
**Current:** `deploy-to-server.sh` always runs `tests/check-ports.sh --core-only` post-deploy, and runs full port checks + `check-tls.sh` when `env=prod` and `certs/server.pem` exists. `deploy.sh` (local) verifies stacks via Caddy automatically.

---

## 5. Documentation

### 5.1 Quick start vs full setup
**Status:** ⏳ Open
**Current:** README is a single flow (setup → deploy → stacks → URLs). No separate "quick start (localhost)" vs "full setup (LAN/HTTPS)" split.

### 5.2 Architecture diagram
**Status:** ✅ Resolved, different doc
**Current:** `docs/NETWORK-CONFIG.md` has an ASCII architecture diagram (LAN → router → internet tunnel options), covering more than the original Browser→Caddy→backend sketch. Nothing in README itself.

---

## Priority Summary

| Priority | Item | Status |
|----------|------|--------|
| P0 | Set N8N_ENCRYPTION_KEY; require/change default password | ✅ Done |
| P1 | Pin n8n image; add `.env.example`; document backup | ⚠️ 2/3 — backup script still missing |
| P2 | Re-enable Postgres when viable; healthchecks; n8n health test | ⚠️ 2/3 — standalone n8n health test still missing |
| P3 | Consolidate config; cert reload doc; deploy test run | ⚠️ Mostly done — n8n symlink and `deploy-litellm.sh` hostname remain |

## Still Open (actionable)

1. `scripts/backup-n8n.sh` — tar/dump n8n data on a schedule, with retention.
2. `tests/check-n8n.sh` (or extend `check-tls.sh`) — standalone n8n health check, independent of a deploy run.
3. Remove `compose/n8n/docker-compose.yaml` symlink.
4. Generalize `PROD_HOST="darragh-pc"` in `scripts/deploy-litellm.sh`.
5. README: note SQLite is dev/single-user only; consider a quick-start/full-setup split.
6. `EXECUTIONS_MODE=queue` + Redis — low priority, only if concurrent workflow load becomes an issue.
7. Native Python task runner for n8n's Code node — new `task-runners` service (`n8nio/runners`) + `N8N_RUNNERS_AUTH_TOKEN` secret; see §2.6.
