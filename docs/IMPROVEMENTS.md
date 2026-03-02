# Project Improvements: Configuration & n8n Reliability

## 1. Configuration Simplification

### 1.1 Single env file for host-specific values
**Current:** `N8N_HOST` and `N8N_EDITOR_BASE_URL` are set in deploy.sh; cert hostnames are prompted or passed to bootstrap-tls.
**Improvement:** Add `.env.example` with `HOST=darragh-pc`, `LAN_IP=192.168.86.237`. Source it from deploy.sh and bootstrap-tls. One place to edit per host.

### 1.2 Consolidate compose file names
**Current:** Both `compose.yaml` and `docker-compose.yaml` (symlinks) in each stack.
**Improvement:** Use only `compose.yaml` and remove symlinks, or document why both exist.

### 1.3 Hardcoded hostname in deploy-to-server
**Current:** Default target is `darragh-pc`; README and docs reference it throughout.
**Improvement:** Add `HOST` or `TARGET` in `.env` and use it in deploy-to-server, README templates, and Windows scripts.

### 1.4 Cert setup: reduce prompts
**Current:** Interactive IP prompt when no args.
**Improvement:** Auto-detect LAN IP as default; `--non-interactive` for CI/scripts.

---

## 2. n8n Reliability (Production-Ready)

### 2.1 Security: N8N_ENCRYPTION_KEY **[High]**
**Current:** Not set; n8n generates one on first run and stores in volume.
**Risk:** If the volume is lost/corrupted, credentials cannot be decrypted. Key is tied to the single instance.
**Improvement:** Generate a persistent key and pass via env:
```yaml
- N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
```
Add to `.env.example`: `N8N_ENCRYPTION_KEY= # generate with: openssl rand -hex 32`

### 2.2 Change default password **[High]**
**Current:** `N8N_BASIC_AUTH_PASSWORD=changeme` is documented.
**Improvement:** Require `N8N_BASIC_AUTH_PASSWORD` from env (no default); fail deploy if unset. Or at minimum: document that it MUST be changed.

### 2.3 Database: Postgres for production **[Medium]**
**Current:** SQLite (commented Postgres due to image pull I/O issues on darragh-pc).
**Risk:** SQLite can corrupt under concurrent load; not recommended for production.
**Improvement:** Re-enable Postgres when storage is stable; or document SQLite as "dev/single-user only". Add optional `compose.n8n-postgres.yaml` override.

### 2.4 Image tag: avoid `latest` **[Medium]**
**Current:** `n8n:latest`
**Risk:** Unpredictable upgrades; breakage on pull.
**Improvement:** Pin to a version, e.g. `n8nio/n8n:1.62.0`, and document upgrade process.

### 2.5 EXECUTIONS_MODE for concurrency **[Low]**
**Current:** Default `regular`.
**Improvement:** For multiple concurrent workflows, `EXECUTIONS_MODE=queue` with Redis. Optional for small setups; document when to enable.

---

## 3. Operational Reliability

### 3.1 Health checks in compose
**Current:** No healthcheck for n8n or Caddy.
**Improvement:** Add healthcheck to n8n (HTTP GET :5678/healthz or similar) and Caddy; `restart: unless-stopped` is good but healthcheck helps orchestrators.

### 3.2 Caddy: cert reload on change
**Current:** Caddy loads certs at start; no reload on file change.
**Improvement:** Document that after `setup-certs.sh`, `podman compose restart` in tls-proxy is required. Or add a `reload-certs.sh` that restarts Caddy.

### 3.3 Backup n8n data
**Current:** No backup strategy.
**Improvement:** Add `scripts/backup-n8n.sh` that tars the n8n-data volume (or dumps SQLite) to a timestamped file. Document retention and off-site copy.

### 3.4 Deploy order / dependencies
**Current:** Stacks deployed in fixed order; no explicit depends_on between tls-proxy and backends.
**Improvement:** Ensure hello-world and n8n start before tls-proxy (or Caddy fails gracefully). Currently Caddy might start first and return 502 until backends are up—document or add retry in Caddy config.

---

## 4. Testing & Validation

### 4.1 Add n8n-specific test
**Current:** check-ports verifies 5678 listening; check-tls doesn’t hit n8n.
**Improvement:** Add `curl -s http://127.0.0.1:5678/healthz` (or equivalent) in check-tls or a new `tests/check-n8n.sh`.

### 4.2 Run tests in deploy
**Improvement:** After deploy, optionally run `tests/check-ports.sh` and `scripts/check-tls.sh`; fail deploy if they fail.

---

## 5. Documentation

### 5.1 Quick start vs full setup
**Improvement:** Split README: "Quick start (localhost)" vs "Full setup (LAN, HTTPS, darragh-pc)".

### 5.2 Architecture diagram
**Improvement:** Add simple diagram: Browser → Caddy (8443/8444) → hello-world (8080) / n8n (5678).

---

## Priority Summary

| Priority | Item |
|----------|------|
| **P0** | Set N8N_ENCRYPTION_KEY; require/changed default password |
| **P1** | Pin n8n image; add .env.example; document backup |
| **P2** | Re-enable Postgres when viable; healthchecks; n8n health test |
| **P3** | Consolidate config; cert reload doc; deploy test run |
