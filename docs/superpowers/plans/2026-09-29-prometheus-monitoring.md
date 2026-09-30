# Prometheus Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Prometheus, Alertmanager and Grafana as tailnet-only stacks that alert to Slack `#myagentchannel` when a stack, endpoint, certificate or host resource goes bad.

**Architecture:** Three new compose stacks (`prometheus` with blackbox + node-exporter sidecars, `alertmanager`, `grafana`) publish on `${HOST_INTERNAL_IP}` and scrape each other and existing apps at `host.containers.internal:<port>` (east-west, per `p-open-east-west`). Only Caddy and LiteLLM are touched (config-only); every other app is probed, not changed. Prometheus and Grafana are mounted no-strip on the existing `:8090` tailnet router.

**Tech Stack:** Podman rootless + podman-compose, Prometheus 3.5, Alertmanager 0.28, Grafana 12.1, blackbox_exporter 0.27, node_exporter 1.9, Caddy, bash, `promtool`/`amtool`/`caddy validate` (run from their images).

**Spec:** `docs/superpowers/specs/2026-09-29-prometheus-monitoring-design.md`

## Global Constraints

- Every published port is `"${HOST_INTERNAL_IP:?HOST_INTERNAL_IP must be set in .env}:<host>:<container>"`. Never `0.0.0.0`, never a hardcoded address.
- New stacks are tailnet-only. No LAN Caddy site, no Funnel, no Cloudflare Tunnel.
- **n8n and GQLDB compose files must be unchanged** (n8n metrics would be public via the Funnel; GQLDB metrics expose `/debug/pprof`). Probe only.
- **Do not change** WordPress, MariaDB, either Postgres, tic-tac-toe, weather-mcp, hello-world or claude-mock-test.
- The n8n Funnel `:443` entry must stay byte-identical (`tailscale funnel status` before/after).
- Secrets live only in `.env`; `.env.example` documents them blank. Slack token never committed.
- Image pins are exact tags. `architecture/model.yaml` must pass `python3 scripts/arch-validate.py` before every deploy (`require_conformant_model()` refuses otherwise).
- Alertmanager must be v0.28+ (bot-token Slack auth). Prometheus runs **without** `--web.enable-lifecycle` (its reload endpoint would be unauthenticated east-west).
- Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Port and name allocation

| Thing | Host port | Container port | Notes |
|---|---|---|---|
| prometheus | 8100 | 9090 | `--web.route-prefix=/prometheus` |
| alertmanager | 8101 | 9093 | host-internal only, no Caddy route |
| grafana | 8102 | 3000 | `serve_from_sub_path`, `/grafana` |
| Caddy metrics site | 8103 | (Caddy, host network) | bound to `${HOST_INTERNAL_IP}` |

Container names follow `<stack>_<service>_1` (e.g. `prometheus_prometheus_1`). `9090` is Cockpit's port, hence 8100.

## Review Focus

- **Blackbox probe that fails but scrape is "up":** the blackbox scrape succeeds even when the probe fails, so `up` alone hides outages. Covered by `ProbeDown` on `probe_success` and by `check-monitoring.sh` asserting no `probe_success == 0` (Task 1, Task 7).
- **Cert probe noise:** the TLS-expiry probe accepts 401/403/404, and must not trip `ProbeDown`. `tls-cert` job is excluded from `ProbeDown` and unit-tested (Task 1).
- **Slack returns HTTP 200 with `ok:false`** on a bad token/channel, so Alertmanager can look healthy while delivering nothing. Task 3 sends a real alert and checks for the message; Task 7 repeats it.
- **Empty `SLACK_BOT_TOKEN`:** compose `:?` must fail loudly rather than start an Alertmanager that silently drops alerts (Task 3).
- **Public-URL probes from the host itself:** hairpin/self-connect can fail (see the WSL2 memory note) even when the site is up externally. Task 1 verifies each and drops any that cannot work from the host, recording why.
- **Router mount regressions:** adding `/prometheus` and `/grafana` handles must not shadow the catch-all index or existing mounts (Task 2 curls existing mounts before/after).
- **LiteLLM `/metrics` reachable on LAN/tailnet:** Task 5 blocks it on the non-east-west sites and tests the 404.

---

## File Structure

| File | Responsibility |
|---|---|
| `compose/prometheus/compose.yaml` | prometheus + blackbox + node-exporter containers |
| `compose/prometheus/prometheus.yml` | scrape jobs, alerting target, rule glob |
| `compose/prometheus/blackbox.yml` | probe modules |
| `compose/prometheus/rules/alerts.yml` | alert rules (mounted into the container) |
| `compose/prometheus/tests/alerts.test.yml` | `promtool test rules` unit tests (not mounted) |
| `compose/alertmanager/compose.yaml`, `alertmanager.yml` | Slack routing |
| `compose/grafana/compose.yaml`, `provisioning/`, `dashboards/` | provisioned Grafana |
| `compose/tls-proxy/Caddyfile` | metrics site, `/prometheus` + `/grafana` routes, LiteLLM metrics block |
| `compose/tls-proxy/router-static/index.html` | links |
| `compose/litellm/config.yaml` | Prometheus callback |
| `scripts/lib/post-deploy-caddy.sh` | verify tailnet-only stacks directly |
| `scripts/check-monitoring.sh` | read-only end-to-end assertion script |
| `architecture/model.yaml`, `.env.example`, `README.md`, `docs/*` | registry and docs |

---

### Task 1: Prometheus stack with probes, host metrics and rules

**Files:**
- Create: `compose/prometheus/compose.yaml`, `prometheus.yml`, `blackbox.yml`, `rules/alerts.yml`, `tests/alerts.test.yml`
- Create: `scripts/check-monitoring.sh`
- Create (via script): `systemd/user/localserver-prometheus.service`; modify `compose/stack-order`
- Modify: `architecture/model.yaml`

**Interfaces:**
- Produces: Prometheus at `http://${HOST_INTERNAL_IP}:8100/prometheus`; jobs `prometheus`, `node`, `probe-http`, `probe-tcp`, `tls-cert`; blackbox at `blackbox:9115` and node-exporter at `node-exporter:9100` on the stack network; alert names `Watchdog`, `TargetDown`, `ProbeDown`, `EndpointSlow`, `CertExpiringSoon`, `CertExpiryCritical`, `HostDiskFilling`, `HostMemoryHigh`, `HostCpuHigh`; `scripts/check-monitoring.sh` (extended in later tasks).
- Consumes: nothing.

- [ ] **Step 0: Record the Funnel baseline** (Task 7 diffs against it)

```bash
tailscale funnel status | tee /tmp/claude-1000/-home-darraghog-dev-localserver-config/cdd6ea69-65bb-4e80-926d-08c9e00928cb/scratchpad/funnel-before.txt
```
Expected: the `:443` n8n entry is listed. If `tailscale` is not usable from this host, run it over `ssh beeblebox` and save the output the same way.

- [ ] **Step 1: Confirm the image tags exist**

```bash
for i in prom/prometheus:v3.5.0 prom/blackbox-exporter:v0.27.0 prom/node-exporter:v1.9.1; do
  podman pull "docker.io/$i" >/dev/null && echo "OK $i" || echo "MISSING $i"
done
```
Expected: three `OK` lines. If one is `MISSING`, pick the nearest existing tag from the registry and use it everywhere this plan mentions the old one (including `model.yaml` in Step 9).

- [ ] **Step 2: Scaffold the stack**

```bash
./scripts/add-service.sh prometheus --port 8100 --container-port 9090 --image docker.io/prom/prometheus:v3.5.0
```
Expected: creates `compose/prometheus/compose.yaml`, adds `prometheus` to `compose/stack-order` before `tls-proxy`, writes `systemd/user/localserver-prometheus.service`. The generated compose is overwritten in Step 5.

- [ ] **Step 3: Write the failing rule tests first**

`compose/prometheus/rules/alerts.yml` does not exist yet, so this fails. Create `compose/prometheus/tests/alerts.test.yml`:

```yaml
rule_files:
  - ../rules/alerts.yml
evaluation_interval: 1m

tests:
  - name: ProbeDown fires after 5m of failure
    interval: 1m
    input_series:
      - series: 'probe_success{job="probe-http",instance="http://x/health"}'
        values: '1 1 0 0 0 0 0 0 0 0 0 0'
    alert_rule_test:
      - eval_time: 4m
        alertname: ProbeDown
        exp_alerts: []
      - eval_time: 10m
        alertname: ProbeDown
        exp_alerts:
          - exp_labels:
              severity: page
              job: probe-http
              instance: http://x/health
            exp_annotations:
              summary: "Probe failing: http://x/health"

  - name: ProbeDown ignores the tls-cert job
    interval: 1m
    input_series:
      - series: 'probe_success{job="tls-cert",instance="https://x"}'
        values: '0 0 0 0 0 0 0 0 0 0 0 0'
    alert_rule_test:
      - eval_time: 10m
        alertname: ProbeDown
        exp_alerts: []

  - name: TargetDown fires after 5m
    interval: 1m
    input_series:
      - series: 'up{job="caddy",instance="h:8103"}'
        values: '1 0 0 0 0 0 0 0 0 0 0 0'
    alert_rule_test:
      - eval_time: 10m
        alertname: TargetDown
        exp_alerts:
          - exp_labels:
              severity: page
              job: caddy
              instance: h:8103
            exp_annotations:
              summary: "Scrape target down: caddy h:8103"

  - name: CertExpiringSoon warns under 14 days but not under 3
    interval: 1m
    input_series:
      - series: 'probe_ssl_earliest_cert_expiry{job="tls-cert",instance="https://x"}'
        values: '864000+0x180'
    alert_rule_test:
      - eval_time: 2h
        alertname: CertExpiringSoon
        exp_alerts:
          - exp_labels:
              severity: warn
              job: tls-cert
              instance: https://x
            exp_annotations:
              summary: "TLS certificate for https://x expires in under 14 days"
      - eval_time: 2h
        alertname: CertExpiryCritical
        exp_alerts: []

  - name: HostDiskFilling fires under 15 percent free
    interval: 1m
    input_series:
      - series: 'node_filesystem_avail_bytes{mountpoint="/",instance="node"}'
        values: '10+0x30'
      - series: 'node_filesystem_size_bytes{mountpoint="/",instance="node"}'
        values: '100+0x30'
    alert_rule_test:
      - eval_time: 20m
        alertname: HostDiskFilling
        exp_alerts:
          - exp_labels:
              severity: warn
              mountpoint: /
              instance: node
            exp_annotations:
              summary: "Root filesystem has under 15% free"

  - name: Watchdog always fires
    interval: 1m
    input_series:
      - series: 'up{job="x"}'
        values: '1+0x5'
    alert_rule_test:
      - eval_time: 3m
        alertname: Watchdog
        exp_alerts:
          - exp_labels:
              severity: none
            exp_annotations:
              summary: "Alerting pipeline heartbeat"
```

- [ ] **Step 4: Run the tests to verify they fail**

```bash
podman run --rm -v "$PWD/compose/prometheus:/w:ro" --entrypoint promtool docker.io/prom/prometheus:v3.5.0 test rules /w/tests/alerts.test.yml
```
Expected: FAIL (cannot read `../rules/alerts.yml`, no such file).

- [ ] **Step 5: Write the rules, config and compose**

`compose/prometheus/rules/alerts.yml`:

```yaml
groups:
  - name: availability
    rules:
      - alert: Watchdog
        expr: vector(1)
        labels:
          severity: none
        annotations:
          summary: "Alerting pipeline heartbeat"
      - alert: TargetDown
        expr: up == 0
        for: 5m
        labels:
          severity: page
        annotations:
          summary: "Scrape target down: {{ $labels.job }} {{ $labels.instance }}"
      - alert: ProbeDown
        expr: probe_success{job!="tls-cert"} == 0
        for: 5m
        labels:
          severity: page
        annotations:
          summary: "Probe failing: {{ $labels.instance }}"
      - alert: EndpointSlow
        expr: probe_duration_seconds{job!="tls-cert"} > 5
        for: 10m
        labels:
          severity: warn
        annotations:
          summary: "Endpoint slow (>5s): {{ $labels.instance }}"

  - name: certificates
    rules:
      - alert: CertExpiringSoon
        expr: (probe_ssl_earliest_cert_expiry{job="tls-cert"} - time()) < 14 * 86400
        for: 1h
        labels:
          severity: warn
        annotations:
          summary: "TLS certificate for {{ $labels.instance }} expires in under 14 days"
      - alert: CertExpiryCritical
        expr: (probe_ssl_earliest_cert_expiry{job="tls-cert"} - time()) < 3 * 86400
        for: 1h
        labels:
          severity: page
        annotations:
          summary: "TLS certificate for {{ $labels.instance }} expires in under 3 days"

  - name: host
    rules:
      - alert: HostDiskFilling
        expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.15
        for: 10m
        labels:
          severity: warn
        annotations:
          summary: "Root filesystem has under 15% free"
      - alert: HostDiskFillingFast
        expr: predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[6h], 24 * 3600) < 0
        for: 30m
        labels:
          severity: warn
        annotations:
          summary: "Root filesystem predicted full within 24h"
      - alert: HostMemoryHigh
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10
        for: 10m
        labels:
          severity: warn
        annotations:
          summary: "Host has under 10% memory available"
      - alert: HostCpuHigh
        expr: 1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) > 0.90
        for: 15m
        labels:
          severity: warn
        annotations:
          summary: "Host CPU over 90% for 15m"
```

`compose/prometheus/blackbox.yml`:

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 10s
    http:
      preferred_ip_protocol: ip4
  tcp_connect:
    prober: tcp
    timeout: 5s
  tls_expiry:
    prober: http
    timeout: 10s
    http:
      preferred_ip_protocol: ip4
      valid_status_codes: [200, 301, 302, 401, 403, 404]
      tls_config:
        insecure_skip_verify: true
```

`compose/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: prometheus
    metrics_path: /prometheus/metrics
    static_configs:
      - targets: ['localhost:9090']

  - job_name: node
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: probe-http
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - http://host.containers.internal:8091/health   # tic-tac-toe
          - http://host.containers.internal:8094/health   # weather-mcp
          - http://host.containers.internal:4000/litellm/health/liveliness
          - http://host.containers.internal:5678/healthz  # n8n
          - http://host.containers.internal:8096/         # wordpress backend
          - http://host.containers.internal:8080/         # hello-world
          - http://host.containers.internal:8093/         # claude-mock-test
          - http://host.containers.internal:3052/         # gqldb console
          - https://thelearningcto.com/                   # public blog
          - https://beeblebox.taile98462.ts.net/healthz   # n8n via public Funnel
    relabel_configs: &blackbox_relabel
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115

  - job_name: probe-tcp
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
          - host.containers.internal:60061                # gqldb gRPC
    relabel_configs: *blackbox_relabel

  - job_name: tls-cert
    metrics_path: /probe
    params:
      module: [tls_expiry]
    static_configs:
      - targets:
          - https://host.containers.internal:8443         # Caddy private-CA cert
    relabel_configs: *blackbox_relabel
```

`compose/prometheus/compose.yaml` (overwrites the scaffold):

```yaml
# Prometheus + blackbox_exporter + node_exporter. Tailnet-only via the :8090 router at
# /prometheus (no-strip). Host-internal: ${HOST_INTERNAL_IP}:8100.
# No --web.enable-lifecycle: its unauthenticated /-/reload would be open to every container.
# Reload config with: podman kill --signal HUP prometheus_prometheus_1
services:
  prometheus:
    image: docker.io/prom/prometheus:v3.5.0
    ports:
      - "${HOST_INTERNAL_IP:?HOST_INTERNAL_IP must be set in .env}:8100:9090"
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=15d
      - --storage.tsdb.retention.size=5GB
      - --web.external-url=https://beeblebox.taile98462.ts.net:8090/prometheus/
      - --web.route-prefix=/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./rules:/etc/prometheus/rules:ro
      - prometheus-data:/prometheus
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:9090/prometheus/-/healthy"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s

  blackbox:
    image: docker.io/prom/blackbox-exporter:v0.27.0
    command: ["--config.file=/etc/blackbox/blackbox.yml"]
    volumes:
      - ./blackbox.yml:/etc/blackbox/blackbox.yml:ro
    restart: unless-stopped

  node-exporter:
    image: docker.io/prom/node-exporter:v1.9.1
    command:
      - --path.rootfs=/host
      - --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run|var/lib/containers)($|/)
    volumes:
      - /:/host:ro,rslave
    restart: unless-stopped

volumes:
  prometheus-data: {}
```

- [ ] **Step 6: Run the tests to verify they pass, and lint the config**

```bash
podman run --rm -v "$PWD/compose/prometheus:/w:ro" --entrypoint promtool docker.io/prom/prometheus:v3.5.0 test rules /w/tests/alerts.test.yml
podman run --rm -v "$PWD/compose/prometheus:/etc/prometheus:ro" --entrypoint promtool docker.io/prom/prometheus:v3.5.0 check config /etc/prometheus/prometheus.yml
```
Expected: `SUCCESS` for the tests; `SUCCESS: ... 1 rule files found` for the config. If a test fails because an annotation is rendered differently, fix the test to match the rule (the rule text is the source of truth).

- [ ] **Step 7: Write the end-to-end check script (fails until deployed)**

Create `scripts/check-monitoring.sh` (`chmod +x`):

```bash
#!/usr/bin/env bash
# Read-only end-to-end check of the monitoring stack. Safe to run any time.
# Usage: ./scripts/check-monitoring.sh
# Env:   CHECK_SKIP_JOBS="litellm caddy"   jobs to not require (used while rolling out)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$REPO_ROOT/.env" ]] && set -a && source "$REPO_ROOT/.env" && set +a
H="${HOST_INTERNAL_IP:?HOST_INTERNAL_IP must be set in .env}"
PROM="http://$H:8100/prometheus"
AM="http://$H:8101"
GF="http://$H:8102/grafana"

fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*" >&2; fail=1; }

curl -fsS "$PROM/-/healthy" >/dev/null 2>&1 && ok "prometheus healthy" || bad "prometheus not healthy at $PROM"

python3 - "$PROM" "${CHECK_SKIP_JOBS:-}" <<'PY' || fail=1
import json, sys, urllib.request, urllib.parse

prom, skip = sys.argv[1], set(sys.argv[2].split())
def get(path):
    return json.load(urllib.request.urlopen(prom + path, timeout=10))

expected = {"prometheus", "node", "probe-http", "probe-tcp", "tls-cert",
            "alertmanager", "grafana", "caddy", "litellm"} - skip
targets = get("/api/v1/targets?state=active")["data"]["activeTargets"]
jobs = {t["labels"]["job"] for t in targets}
rc = 0
for j in sorted(expected - jobs):
    print(f"FAIL missing scrape job: {j}", file=sys.stderr); rc = 1
for t in targets:
    if t["labels"]["job"] in skip:
        continue
    if t["health"] != "up":
        print(f"FAIL target down: {t['labels']['job']} {t['labels']['instance']} ({t.get('lastError','')})", file=sys.stderr); rc = 1
res = get("/api/v1/query?" + urllib.parse.urlencode({"query": 'probe_success{job!="tls-cert"} == 0'}))["data"]["result"]
for r in res:
    print(f"FAIL probe failing: {r['metric'].get('instance')}", file=sys.stderr); rc = 1
res = get("/api/v1/query?" + urllib.parse.urlencode({"query": 'ALERTS{alertname="Watchdog",alertstate="firing"}'}))["data"]["result"]
if not res:
    print("FAIL Watchdog is not firing (rules not loaded?)", file=sys.stderr); rc = 1
if rc == 0:
    print("OK   all expected targets up, no failing probes, Watchdog firing")
sys.exit(rc)
PY

if [[ " ${CHECK_SKIP_JOBS:-} " != *" alertmanager "* ]]; then
  curl -fsS "$AM/-/ready" >/dev/null 2>&1 && ok "alertmanager ready" || bad "alertmanager not ready at $AM"
fi
if [[ " ${CHECK_SKIP_JOBS:-} " != *" grafana "* ]]; then
  out="$(curl -fsS -u "admin:${GRAFANA_ADMIN_PASSWORD:-}" "$GF/api/datasources/uid/prometheus/health" 2>/dev/null || true)"
  [[ "$out" == *'"status":"OK"'* ]] && ok "grafana datasource healthy" || bad "grafana datasource unhealthy: ${out:-no response}"
fi

exit "$fail"
```

- [ ] **Step 8: Add the model entries**

In `architecture/model.yaml`:

Under `ApplicationComponent:` (after `ac-gqldb`):

```yaml
  - id: ac-prometheus
    name: Prometheus
    stack: compose/prometheus
    image: prom/prometheus:v3.5.0 + prom/blackbox-exporter:v0.27.0 + prom/node-exporter:v1.9.1
    routing: no-strip
    lifecycle: production
    description: >
      Metrics store, rule evaluator and probe scheduler. Scrapes metric endpoints where an
      application already exposes them and blackbox-probes the rest; changes no application.
```

Under `ApplicationService:` (after `as-gqldb`):

```yaml
  - id: as-prometheus
    name: Prometheus UI and API
    endpoint: https://beeblebox.taile98462.ts.net:8090/prometheus/
    protocol: https
    auth: network-identity
    description: Query UI and API on the tailnet path router. Also answers east-west on the host-internal port.
```

Under `DataEntity:` and `DataStore:` (next to the gqldb entries):

```yaml
  - id: de-monitoring-metrics
    name: Monitoring time series
    classification: internal
    recoverability: recoverable
    description: Fifteen days of scraped metrics. Disposable by design; nothing is lost that matters if it is.
```

```yaml
  - id: ds-prometheus-tsdb
    name: Prometheus TSDB
    technology: Podman volume
    backup_method: none
    description: Deliberately not backed up - metrics are disposable and rebuilt from the next scrape.
```

Under `relationships:` (in each existing group; keep the file's grouping):

```yaml
  - { from: cap-administration, name: realised_by, to: ac-prometheus }
  - { from: ac-prometheus,      name: provides, to: as-prometheus }
  - { from: as-prometheus,      name: delivers, to: bs-administration }
  - { from: as-prometheus,      name: exposed_via, to: et-tailnet }
  - { from: ac-prometheus,      name: manages, to: de-monitoring-metrics }
  - { from: de-monitoring-metrics, name: persisted_in, to: ds-prometheus-tsdb }
  - { from: ac-prometheus,      name: deployed_on, to: n-beeblebox }
  - { from: ac-prometheus,      name: depends_on, to: ts-podman }
  - { from: ctl-tailnet-identity, name: protects, to: as-prometheus }
```

- [ ] **Step 9: Validate the model**

```bash
python3 scripts/arch-validate.py
```
Expected: exits 0. If it reports an unknown enum or missing attribute, fix the entry to match `architecture/metamodel.yaml` (the validator's message names the field). `backup_method: none` on a `recoverable` entity must not trip the irreplaceable-data invariant; if the validator objects, read the invariant and adjust the entity classification rather than the invariant.

- [ ] **Step 10: Install the unit and deploy** (`bootstrap-host.sh` needs sudo: ask the user to run `! ./scripts/sudo/bootstrap-host.sh`)

```bash
./scripts/deploy-stack.sh prometheus
```
Expected: stack up. The post-deploy step may report a FAIL for the Caddy front door; that is fixed in Task 2. If the failure is anything else, stop and diagnose.

- [ ] **Step 11: Verify targets**

```bash
CHECK_SKIP_JOBS="alertmanager grafana caddy litellm" ./scripts/check-monitoring.sh
```
Expected: `OK` lines and exit 0. For each `FAIL probe failing:` decide: a real outage (report to the user), or an unreachable-by-design probe. The public URLs (`thelearningcto.com`, the `ts.net/healthz` Funnel URL) may fail from the host itself (hairpin); if one does, confirm with `curl -sS <url>` from the host, remove that target from `probe-http` with a comment saying why, and `podman kill --signal HUP prometheus_prometheus_1`.

Also confirm node-exporter sees the host's root filesystem, not the container's:

```bash
curl -s "http://${HOST_INTERNAL_IP:-127.0.0.1}:8100/prometheus/api/v1/query" --data-urlencode 'query=node_filesystem_size_bytes{mountpoint="/"}'
df -B1 --output=size / | tail -1
```
Expected: the two sizes agree. If not, adjust the `--path.rootfs` / mount options until they do.

- [ ] **Step 12: Commit**

```bash
git add compose/prometheus compose/stack-order systemd/user/localserver-prometheus.service scripts/check-monitoring.sh architecture/model.yaml
git commit -m "Add a Prometheus stack with blackbox probes, host metrics and alert rules

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Caddy metrics, tailnet routes and tailnet-only post-deploy verification

**Files:**
- Modify: `compose/tls-proxy/Caddyfile`, `compose/tls-proxy/router-static/index.html`
- Modify: `scripts/lib/post-deploy-caddy.sh`
- Modify: `scripts/check-monitoring.sh` (none needed; `caddy` job is already expected)
- Modify: `compose/prometheus/prometheus.yml`

**Interfaces:**
- Consumes: Task 1 Prometheus on `:8100`.
- Produces: Caddy metrics at `${HOST_INTERNAL_IP}:8103/metrics`; router mounts `/prometheus/` and `/grafana/` (grafana backend on `:8102`, live after Task 4); `post-deploy-caddy.sh` accepts `prometheus`, `alertmanager`, `grafana` as tailnet-only stacks.

- [ ] **Step 1: Record the router baseline (the failing "test")**

```bash
for p in cockpit/ tictactoe/ helloworld/ claudemock/ weather/ litellm/; do
  printf '%s ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:8090/$p"
done | tee /tmp/claude-1000/-home-darraghog-dev-localserver-config/cdd6ea69-65bb-4e80-926d-08c9e00928cb/scratchpad/router-before.txt
curl -s -o /dev/null -w 'prometheus %{http_code}\n' http://127.0.0.1:8090/prometheus/-/healthy
```
Expected: existing mounts give their normal codes; the prometheus line gives `200`-less result (the catch-all serves the index, so likely `200` HTML or `404`). Note the values; the point of the last line is that after this task it must return Prometheus's health text.

- [ ] **Step 2: Enable Caddy metrics and add the metrics site**

In the global options block at the top of `compose/tls-proxy/Caddyfile`, after `auto_https off`, add:

```
	servers {
		metrics
	}
```

Add a new site after the `:8098` block:

```
# Prometheus scrape target for Caddy's own metrics. Bound to the host-internal address
# (not 0.0.0.0, not loopback-for-tailscale): reachable by containers, not by the LAN or
# tailnet. Only /metrics is served; the admin API on :2019 stays untouched.
:8103 {
  bind {env.HOST_INTERNAL_IP}
  metrics /metrics
}
```

Update the header comment (lines 5-15 of the Caddyfile) with: `# :8103 is Caddy's host-internal metrics site (Prometheus scrape only).`

- [ ] **Step 3: Add the router mounts**

In the `:8090` site, add `redir` lines next to the others:

```
  redir /prometheus /prometheus/
  redir /grafana /grafana/
```

and, before the trailing comment about n8n / the catch-all `handle {`, add:

```
  # No strip: prometheus runs with --web.route-prefix=/prometheus and grafana with
  # serve_from_sub_path, so both expect to see their own prefix (same pattern as litellm).
  handle /prometheus/* {
    reverse_proxy {env.HOST_INTERNAL_IP}:8100
  }
  handle /grafana/* {
    reverse_proxy {env.HOST_INTERNAL_IP}:8102
  }
```

- [ ] **Step 4: Add index links**

In `compose/tls-proxy/router-static/index.html`, under the "Tailnet-only (this port)" list, add after the `helloworld` item:

```html
    <li><a href="/prometheus/">prometheus</a> — metrics and alerts</li>
    <li><a href="/grafana/">grafana</a> — dashboards</li>
```

- [ ] **Step 5: Validate the Caddyfile**

```bash
podman run --rm -e HOST_INTERNAL_IP="${HOST_INTERNAL_IP:-127.0.0.1}" -v "$PWD/compose/tls-proxy/Caddyfile:/etc/caddy/Caddyfile:ro" -v "$PWD/certs:/certs:ro" docker.io/library/caddy:alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```
Expected: `Valid configuration`. If `servers { metrics }` is rejected, the running Caddy is newer; use the global `metrics` option instead (`metrics` as a top-level line in the global block).

- [ ] **Step 6: Make post-deploy verification understand tailnet-only stacks**

In `scripts/lib/post-deploy-caddy.sh`:

1. In `caddy_verify_path_for_stack`, add cases:

```bash
    prometheus) printf '%s' "/prometheus/-/healthy" ;;
    alertmanager) printf '%s' "/-/healthy" ;;
    grafana) printf '%s' "/grafana/api/health" ;;
```

2. In `caddy_backend_host_for_backend`, make the fallback host-aware:

```bash
  printf '%s' "${out:-${HOST_INTERNAL_IP:-127.0.0.1}}"
```

3. In `verify_deployed_stacks_via_caddy`, immediately after the `be="$(compose_first_published_host_port ...)" || continue` line, add:

```bash
    # Tailnet-only monitoring stacks have no LAN Caddy door (the :8090 router is plain HTTP),
    # so probe the backend directly rather than an HTTPS front door that does not exist.
    case "$s" in
      prometheus|alertmanager|grafana)
        if wait_for_stack_backend "$s" "$be"; then
          echo "[post-deploy-caddy] OK $s (backend healthy; tailnet-only, no LAN Caddy door)"
        else
          failed=1
        fi
        continue
        ;;
    esac
```

- [ ] **Step 7: Add the Caddy scrape job**

Append to `scrape_configs` in `compose/prometheus/prometheus.yml`:

```yaml
  - job_name: caddy
    metrics_path: /metrics
    static_configs:
      - targets: ['host.containers.internal:8103']
```

Then: `podman run --rm -v "$PWD/compose/prometheus:/etc/prometheus:ro" --entrypoint promtool docker.io/prom/prometheus:v3.5.0 check config /etc/prometheus/prometheus.yml` (expect SUCCESS).

- [ ] **Step 8: Deploy and verify**

```bash
./scripts/deploy-stack.sh prometheus tls-proxy
curl -s http://127.0.0.1:8090/prometheus/-/healthy
for p in cockpit/ tictactoe/ helloworld/ claudemock/ weather/ litellm/; do
  printf '%s ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:8090/$p"
done | diff - /tmp/claude-1000/-home-darraghog-dev-localserver-config/cdd6ea69-65bb-4e80-926d-08c9e00928cb/scratchpad/router-before.txt && echo "router unchanged"
podman exec prometheus_prometheus_1 wget -qO- http://host.containers.internal:8103/metrics | head -3
CHECK_SKIP_JOBS="alertmanager grafana litellm" ./scripts/check-monitoring.sh
```
Expected: `Prometheus Server is Healthy.`; `router unchanged`; Caddy metric lines from inside the container; check script exits 0 including the `caddy` job. Also confirm the metrics site is not reachable off-host: from another machine on the LAN or tailnet `curl -m 3 http://<host-lan-ip>:8103/metrics` must fail (skip if no second machine is available, and say so).

- [ ] **Step 9: Check the Windows LAN-port script does not re-publish 8103**

```bash
grep -n "Caddyfile\|bind\|loopback" scripts/setup-windows-podman-lan-ports.ps1 | head -20
```
If the script forwards every `:PORT {` site regardless of `bind`, add an exclusion for 8103 (and note the existing loopback sites 8090/8092/8098 already rely on the same behaviour, so match how they are handled). If it already skips non-`0.0.0.0` binds, no change.

- [ ] **Step 10: Commit**

```bash
git add compose/tls-proxy compose/prometheus/prometheus.yml scripts/lib/post-deploy-caddy.sh scripts/setup-windows-podman-lan-ports.ps1
git commit -m "Expose Caddy metrics and mount prometheus and grafana on the tailnet router

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
(Omit the `.ps1` path if unchanged.)

---

### Task 3: Alertmanager with Slack delivery

**Files:**
- Create: `compose/alertmanager/compose.yaml`, `compose/alertmanager/alertmanager.yml`, `systemd/user/localserver-alertmanager.service` (via script)
- Modify: `compose/stack-order`, `compose/prometheus/prometheus.yml`, `.env.example`, `architecture/model.yaml`

**Interfaces:**
- Consumes: Prometheus rules from Task 1 (`severity` label values `page`, `warn`, `none`).
- Produces: Alertmanager at `${HOST_INTERNAL_IP}:8101`; `SLACK_BOT_TOKEN` env contract; Prometheus `alerting` block and `alertmanager` scrape job.

- [ ] **Step 1: Confirm the image and its Slack bot-token support**

```bash
podman pull docker.io/prom/alertmanager:v0.28.1 && podman run --rm --entrypoint /bin/alertmanager docker.io/prom/alertmanager:v0.28.1 --version
```
Expected: version `0.28.1` or newer. If the tag is missing, choose the newest 0.28+ tag.

- [ ] **Step 2: Scaffold**

```bash
./scripts/add-service.sh alertmanager --port 8101 --container-port 9093 --image docker.io/prom/alertmanager:v0.28.1
```

- [ ] **Step 3: Write the failing config check**

Create `compose/alertmanager/alertmanager.yml`:

```yaml
route:
  receiver: slack
  group_by: [alertname]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - receiver: "null"
      matchers:
        - alertname="Watchdog"

receivers:
  - name: "null"
  - name: slack
    slack_configs:
      - api_url: https://slack.com/api/chat.postMessage
        http_config:
          authorization:
            type: Bearer
            credentials_file: /tmp/slack_token
        channel: '#myagentchannel'
        send_resolved: true
        title: '{{ if eq .Status "firing" }}:rotating_light:{{ else }}:white_check_mark:{{ end }} [{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ "\n" }}{{ end }}'
```

Run: 

```bash
podman run --rm -v "$PWD/compose/alertmanager:/w:ro" --entrypoint amtool docker.io/prom/alertmanager:v0.28.1 check-config /w/alertmanager.yml
```
Expected: FAIL: `/tmp/slack_token` does not exist in the checker container. That proves the config really references the file. Create it in a throwaway way to check syntax:

```bash
podman run --rm -v "$PWD/compose/alertmanager:/w:ro" --entrypoint /bin/sh docker.io/prom/alertmanager:v0.28.1 -c 'echo x > /tmp/slack_token && amtool check-config /w/alertmanager.yml'
```
Expected: `SUCCESS` with 2 receivers. If it rejects `authorization` under `http_config` the version is too old; return to Step 1.

- [ ] **Step 4: Write the compose file**

Overwrite `compose/alertmanager/compose.yaml`:

```yaml
# Alertmanager -> Slack #myagentchannel via chat.postMessage (bot token, same as the
# slack-publish-myagentchannel skill). Host-internal only: no Caddy site, no tailnet path.
# The token comes from .env; it is written to a 0600 file at start because Alertmanager
# reads bearer credentials from a file, not from the environment.
services:
  alertmanager:
    image: docker.io/prom/alertmanager:v0.28.1
    ports:
      - "${HOST_INTERNAL_IP:?HOST_INTERNAL_IP must be set in .env}:8101:9093"
    environment:
      SLACK_BOT_TOKEN: ${SLACK_BOT_TOKEN:?SLACK_BOT_TOKEN must be set in .env}
    entrypoint: ["/bin/sh", "-c"]
    command:
      - umask 077; printenv SLACK_BOT_TOKEN > /tmp/slack_token; exec /bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/alertmanager
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager-data:/alertmanager
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:9093/-/healthy"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s

volumes:
  alertmanager-data: {}
```

- [ ] **Step 5: Wire Prometheus to it and document the env var**

Append to `compose/prometheus/prometheus.yml` (top level, after `rule_files`) :

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['host.containers.internal:8101']
```

and to `scrape_configs`:

```yaml
  - job_name: alertmanager
    static_configs:
      - targets: ['host.containers.internal:8101']
```

Add to `.env.example`:

```
# --- monitoring -----------------------------------------------------------
# Slack bot token (xoxb-...) used by Alertmanager to post to #myagentchannel via
# chat.postMessage - the same token the slack-publish-myagentchannel skill uses. The bot must
# already be a member of #myagentchannel. Required: alertmanager refuses to start without it.
SLACK_BOT_TOKEN=
```

Ask the user to put the real token in `.env` (`! grep -c '^SLACK_BOT_TOKEN=xoxb' .env` should print 1).

- [ ] **Step 6: Model entries**

`ApplicationComponent`:

```yaml
  - id: ac-alertmanager
    name: Alertmanager
    stack: compose/alertmanager
    image: prom/alertmanager:v0.28.1
    routing: not-path-mounted
    lifecycle: production
    description: Groups Prometheus alerts and delivers them to Slack #myagentchannel.
```

`ApplicationService`:

```yaml
  - id: as-alertmanager
    name: Alertmanager API
    endpoint: http://127.0.0.1:8101
    protocol: http
    auth: none
    description: >
      Host-internal only; Prometheus is its only caller. No Caddy route, so it is not reachable
      from the LAN or tailnet. Unauthenticated east-west like every published endpoint.
```

`ExternalProvider` (after `ep-tailscale`):

```yaml
  - id: ep-slack
    name: Slack
    function: Alert delivery to #myagentchannel via chat.postMessage
    cost: free tier
    lock_in: low
    description: >
      Outbound-only HTTPS from Alertmanager. Substitutable by any notifier Alertmanager
      supports; the bot token is the one secret involved.
```

`relationships:`

```yaml
  - { from: cap-administration, name: realised_by, to: ac-alertmanager }
  - { from: ac-alertmanager,    name: provides, to: as-alertmanager }
  - { from: as-alertmanager,    name: delivers, to: bs-administration }
  - { from: as-alertmanager,    name: exposed_via, to: et-loopback }
  - { from: ac-alertmanager,    name: deployed_on, to: n-beeblebox }
  - { from: ac-alertmanager,    name: depends_on, to: ts-podman }
  - { from: ac-alertmanager,    name: depends_on, to: ep-slack }
  - { from: p-no-inbound,       name: governs, to: ep-slack }
```

Run `python3 scripts/arch-validate.py` (expect exit 0).

- [ ] **Step 7: Deploy and prove delivery**

```bash
./scripts/deploy-stack.sh alertmanager
podman kill --signal HUP prometheus_prometheus_1
CHECK_SKIP_JOBS="grafana litellm" ./scripts/check-monitoring.sh
```
Expected: check exits 0 (alertmanager ready, `alertmanager` job up).

Then send one real alert. **This posts to `#myagentchannel`.**

```bash
curl -sS -XPOST "http://${HOST_INTERNAL_IP:-127.0.0.1}:8101/api/v2/alerts" -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"MonitoringSetupTest","severity":"warn"},"annotations":{"summary":"Test alert from the Prometheus rollout - safe to ignore"}}]'
sleep 45
podman logs --tail 20 alertmanager_alertmanager_1 2>&1 | grep -iE "notify|slack|error" || true
```
Expected: no `notify ... failed`/`ok:false` in the log, and the message appears in `#myagentchannel` after the 30s `group_wait`. Ask the user to confirm they see it. If Slack returned an error (`channel_not_found`, `not_in_channel`, `invalid_auth`), the log will say so: fix the token/channel membership, not the config. Never proceed on "no error logged" alone.

- [ ] **Step 8: Prove the empty-token failure is loud**

```bash
SLACK_BOT_TOKEN= ./scripts/start-stack.sh alertmanager up 2>&1 | tail -3
```
Expected: `SLACK_BOT_TOKEN must be set in .env`. (`start-stack.sh` sources `.env` with `set -a`, so if `.env` supplies the token this test cannot override it. In that case verify instead with `podman-compose -f compose/alertmanager/compose.yaml config` from a shell where the variable is unset and `.env` is not sourced.) Then restart the stack normally so it is running: `./scripts/start-stack.sh alertmanager restart`.

- [ ] **Step 9: Commit**

```bash
git add compose/alertmanager compose/stack-order systemd/user/localserver-alertmanager.service compose/prometheus/prometheus.yml .env.example architecture/model.yaml
git commit -m "Add Alertmanager delivering to Slack via chat.postMessage

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Grafana with provisioned datasource and dashboards

**Files:**
- Create: `compose/grafana/compose.yaml`
- Create: `compose/grafana/provisioning/datasources/prometheus.yaml`, `compose/grafana/provisioning/dashboards/dashboards.yaml`
- Create: `compose/grafana/dashboards/host.json`, `probes.json`, `caddy.json`, `litellm.json`
- Create (via script): `systemd/user/localserver-grafana.service`; modify `compose/stack-order`, `compose/prometheus/prometheus.yml`, `.env.example`, `architecture/model.yaml`

**Interfaces:**
- Consumes: Prometheus at `host.containers.internal:8100/prometheus`; router mount `/grafana/` from Task 2.
- Produces: datasource with uid `prometheus`; Grafana at `${HOST_INTERNAL_IP}:8102`, served under `/grafana`; `GRAFANA_ADMIN_PASSWORD` env contract; `grafana` scrape job.

- [ ] **Step 1: Confirm the image and scaffold**

```bash
podman pull docker.io/grafana/grafana:12.1.0
./scripts/add-service.sh grafana --port 8102 --container-port 3000 --image docker.io/grafana/grafana:12.1.0
```
Expected: pull succeeds (else pick the nearest existing tag and update the compose file).

- [ ] **Step 2: Write the compose file**

Overwrite `compose/grafana/compose.yaml`:

```yaml
# Grafana. Tailnet-only, mounted no-strip on the :8090 router at /grafana. Everything is
# provisioned from files in this directory; nothing is configured by hand in the UI.
services:
  grafana:
    image: docker.io/grafana/grafana:12.1.0
    ports:
      - "${HOST_INTERNAL_IP:?HOST_INTERNAL_IP must be set in .env}:8102:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?GRAFANA_ADMIN_PASSWORD must be set in .env}
      GF_SERVER_ROOT_URL: https://beeblebox.taile98462.ts.net:8090/grafana/
      GF_SERVER_SERVE_FROM_SUB_PATH: "true"
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_AUTH_ANONYMOUS_ENABLED: "false"
      GF_ANALYTICS_REPORTING_ENABLED: "false"
      GF_ANALYTICS_CHECK_FOR_UPDATES: "false"
      GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES: "false"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning:ro
      - ./dashboards:/var/lib/grafana-dashboards:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:3000/grafana/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

volumes:
  grafana-data: {}
```

Add to `.env.example` under the monitoring heading:

```
# Grafana admin password (required). Generate with: openssl rand -base64 24
GRAFANA_ADMIN_PASSWORD=
```

Ask the user to set it in `.env`.

- [ ] **Step 3: Provisioning files**

`compose/grafana/provisioning/datasources/prometheus.yaml`:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://host.containers.internal:8100/prometheus
    isDefault: true
    editable: false
```

`compose/grafana/provisioning/dashboards/dashboards.yaml`:

```yaml
apiVersion: 1
providers:
  - name: estate
    folder: Estate
    type: file
    disableDeletion: true
    allowUiUpdates: false
    options:
      path: /var/lib/grafana-dashboards
```

- [ ] **Step 4: Dashboards**

Each file below is a complete dashboard. All panels use datasource `{"type":"prometheus","uid":"prometheus"}`.

`compose/grafana/dashboards/host.json`:

```json
{
  "uid": "estate-host", "title": "Host", "schemaVersion": 39, "version": 1, "refresh": "30s",
  "time": {"from": "now-6h", "to": "now"},
  "panels": [
    {"id": 1, "type": "timeseries", "title": "CPU busy", "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "percentunit", "min": 0, "max": 1}, "overrides": []},
     "targets": [{"refId": "A", "expr": "1 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))", "legendFormat": "cpu"}]},
    {"id": 2, "type": "timeseries", "title": "Memory available", "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "percentunit", "min": 0, "max": 1}, "overrides": []},
     "targets": [{"refId": "A", "expr": "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes", "legendFormat": "available"}]},
    {"id": 3, "type": "timeseries", "title": "Root filesystem free", "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "percentunit", "min": 0, "max": 1}, "overrides": []},
     "targets": [{"refId": "A", "expr": "node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}", "legendFormat": "free"}]},
    {"id": 4, "type": "timeseries", "title": "Network throughput", "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "Bps"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "sum(rate(node_network_receive_bytes_total{device!~\"lo|veth.*|cni.*|podman.*\"}[5m]))", "legendFormat": "rx"},
                 {"refId": "B", "expr": "sum(rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|cni.*|podman.*\"}[5m]))", "legendFormat": "tx"}]}
  ]
}
```

`compose/grafana/dashboards/probes.json`:

```json
{
  "uid": "estate-probes", "title": "Probes", "schemaVersion": 39, "version": 1, "refresh": "30s",
  "time": {"from": "now-6h", "to": "now"},
  "panels": [
    {"id": 1, "type": "stat", "title": "Endpoint status", "gridPos": {"h": 10, "w": 24, "x": 0, "y": 0},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "color": {"mode": "thresholds"}, "thresholds": {"mode": "absolute", "steps": [{"color": "red", "value": null}, {"color": "green", "value": 1}]}}, "overrides": []},
     "options": {"colorMode": "background", "textMode": "value_and_name"},
     "targets": [{"refId": "A", "expr": "probe_success{job!=\"tls-cert\"}", "legendFormat": "{{instance}}"}]},
    {"id": 2, "type": "timeseries", "title": "Probe duration", "gridPos": {"h": 9, "w": 12, "x": 0, "y": 10},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "s"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "probe_duration_seconds{job!=\"tls-cert\"}", "legendFormat": "{{instance}}"}]},
    {"id": 3, "type": "stat", "title": "Certificate days remaining", "gridPos": {"h": 9, "w": 12, "x": 12, "y": 10},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "d", "decimals": 0, "thresholds": {"mode": "absolute", "steps": [{"color": "red", "value": null}, {"color": "orange", "value": 3}, {"color": "green", "value": 14}]}, "color": {"mode": "thresholds"}}, "overrides": []},
     "targets": [{"refId": "A", "expr": "(probe_ssl_earliest_cert_expiry{job=\"tls-cert\"} - time()) / 86400", "legendFormat": "{{instance}}"}]}
  ]
}
```

`compose/grafana/dashboards/caddy.json`:

```json
{
  "uid": "estate-caddy", "title": "Caddy", "schemaVersion": 39, "version": 1, "refresh": "30s",
  "time": {"from": "now-6h", "to": "now"},
  "panels": [
    {"id": 1, "type": "timeseries", "title": "Requests per second by code", "gridPos": {"h": 9, "w": 12, "x": 0, "y": 0},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "reqps"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "sum by (code) (rate(caddy_http_requests_total[5m]))", "legendFormat": "{{code}}"}]},
    {"id": 2, "type": "timeseries", "title": "Request duration p95", "gridPos": {"h": 9, "w": 12, "x": 12, "y": 0},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "s"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "histogram_quantile(0.95, sum by (le) (rate(caddy_http_request_duration_seconds_bucket[5m])))", "legendFormat": "p95"}]}
  ]
}
```

`compose/grafana/dashboards/litellm.json`:

```json
{
  "uid": "estate-litellm", "title": "LiteLLM", "schemaVersion": 39, "version": 1, "refresh": "30s",
  "time": {"from": "now-24h", "to": "now"},
  "panels": [
    {"id": 1, "type": "timeseries", "title": "Requests per minute by model", "gridPos": {"h": 9, "w": 12, "x": 0, "y": 0},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "short"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "sum by (model) (rate(litellm_proxy_total_requests_metric_total[5m])) * 60", "legendFormat": "{{model}}"}]},
    {"id": 2, "type": "timeseries", "title": "Failed requests per minute", "gridPos": {"h": 9, "w": 12, "x": 12, "y": 0},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "short"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "sum(rate(litellm_proxy_failed_requests_metric_total[5m])) * 60", "legendFormat": "failed"}]},
    {"id": 3, "type": "timeseries", "title": "Spend (USD) by model", "gridPos": {"h": 9, "w": 24, "x": 0, "y": 9},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "currencyUSD"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "sum by (model) (increase(litellm_spend_metric_total[1h]))", "legendFormat": "{{model}}"}]}
  ]
}
```
(The LiteLLM metric names are those LiteLLM documents; Task 5 Step 4 checks they exist and corrects the queries if not.)

Validate JSON: `for f in compose/grafana/dashboards/*.json; do python3 -m json.tool "$f" >/dev/null && echo "OK $f"; done` (expect four OK).

- [ ] **Step 5: Model entries and scrape job**

`ApplicationComponent`:

```yaml
  - id: ac-grafana
    name: Grafana
    stack: compose/grafana
    image: grafana/grafana:12.1.0
    routing: no-strip
    lifecycle: production
    description: Dashboards over Prometheus. Datasource and dashboards are provisioned from git.
```

`ApplicationService`:

```yaml
  - id: as-grafana
    name: Grafana
    endpoint: https://beeblebox.taile98462.ts.net:8090/grafana/
    protocol: https
    auth: basic
    description: Dashboards on the tailnet path router; authenticates callers itself.
```

`relationships:`

```yaml
  - { from: cap-administration, name: realised_by, to: ac-grafana }
  - { from: ac-grafana,         name: provides, to: as-grafana }
  - { from: as-grafana,         name: delivers, to: bs-administration }
  - { from: as-grafana,         name: exposed_via, to: et-tailnet }
  - { from: ac-grafana,         name: deployed_on, to: n-beeblebox }
  - { from: ac-grafana,         name: depends_on, to: ts-podman }
  - { from: ctl-tailnet-identity, name: protects, to: as-grafana }
```

Run `python3 scripts/arch-validate.py` (exit 0).

- [ ] **Step 6: Deploy; find Grafana's metrics path**

```bash
./scripts/deploy-stack.sh grafana
curl -s -o /dev/null -w 'sub-path metrics: %{http_code}\n' "http://${HOST_INTERNAL_IP:-127.0.0.1}:8102/grafana/metrics"
curl -s -o /dev/null -w 'root metrics: %{http_code}\n'     "http://${HOST_INTERNAL_IP:-127.0.0.1}:8102/metrics"
```
Expected: exactly one path returns `200`. Add the scrape job with that path to `compose/prometheus/prometheus.yml`:

```yaml
  - job_name: grafana
    metrics_path: /grafana/metrics     # use /metrics if only the root path answered
    static_configs:
      - targets: ['host.containers.internal:8102']
```

Then `podman kill --signal HUP prometheus_prometheus_1`.

- [ ] **Step 7: Verify sub-path serving through the router**

```bash
curl -s -o /dev/null -w 'login page via router: %{http_code}\n' http://127.0.0.1:8090/grafana/login
curl -s http://127.0.0.1:8090/grafana/login | grep -o '/grafana/public/build/[^"]*' | head -1
CHECK_SKIP_JOBS="litellm" ./scripts/check-monitoring.sh
```
Expected: `200`; an asset URL prefixed `/grafana/public/...` (proving assets are prefix-relative, not root-absolute); check script exits 0, including the Grafana datasource health line.

**Fallback if assets are root-absolute or the login loops:** give Grafana a dedicated tailnet port instead (as gqldb/litellm did): add a `:8099 { bind 127.0.0.1; reverse_proxy {env.HOST_INTERNAL_IP}:8102 }` site, drop `GF_SERVER_SERVE_FROM_SUB_PATH`/`/grafana` from the compose file, health check and scrape path, ask the user to run `ssh beeblebox tailscale serve --bg --https=8099 http://127.0.0.1:8099`, and link it from the router index instead of mounting it. Record the reason in a Caddyfile comment.

- [ ] **Step 8: Open Grafana and look at the dashboards**

Ask the user to open `https://beeblebox.taile98462.ts.net:8090/grafana/`, log in as `admin`, and confirm the Estate folder shows Host, Probes, Caddy and LiteLLM with data in Host, Probes and Caddy (LiteLLM stays empty until Task 5).

- [ ] **Step 9: Commit**

```bash
git add compose/grafana compose/stack-order systemd/user/localserver-grafana.service compose/prometheus/prometheus.yml .env.example architecture/model.yaml
git commit -m "Add Grafana with provisioned Prometheus datasource and estate dashboards

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: LiteLLM Prometheus callback (gated on licence)

**Files:**
- Modify: `compose/litellm/config.yaml`, `compose/tls-proxy/Caddyfile`, `compose/prometheus/prometheus.yml`, possibly `compose/grafana/dashboards/litellm.json`
- Modify: `docs/superpowers/specs/2026-09-29-prometheus-monitoring-design.md` (only if the gate fails)

**Interfaces:**
- Consumes: Grafana `litellm.json` from Task 4.
- Produces: `litellm` scrape job at `/litellm/metrics`; `/litellm/metrics` returns 404 on Caddy's LAN/tailnet sites.

- [ ] **Step 1: Enable the callback**

In `compose/litellm/config.yaml` under `litellm_settings:` add:

```yaml
  callbacks: ["prometheus"]
```

- [ ] **Step 2: Restart LiteLLM and test the licence gate**

```bash
./scripts/deploy-stack.sh litellm
curl -s -o /tmp/claude-1000/-home-darraghog-dev-localserver-config/cdd6ea69-65bb-4e80-926d-08c9e00928cb/scratchpad/litellm-metrics.txt -w '%{http_code}\n' "http://${HOST_INTERNAL_IP:-127.0.0.1}:4000/litellm/metrics"
grep -c '^litellm_' /tmp/claude-1000/-home-darraghog-dev-localserver-config/cdd6ea69-65bb-4e80-926d-08c9e00928cb/scratchpad/litellm-metrics.txt
podman logs --tail 40 litellm_litellm_1 2>&1 | grep -iE "prometheus|enterprise|license|error" || true
```
Expected on success: `200` and a count above 0. **If the endpoint is 404/401, the count is 0, or the log says the callback needs an enterprise licence: stop.** Revert the `config.yaml` change, redeploy litellm, change the spec's LiteLLM row to "probe only (callback is licence-gated on `main-stable`)" and note that in the commit; skip Steps 3-5 and continue to Task 6, removing `litellm` from the expected jobs in `scripts/check-monitoring.sh` and the LiteLLM dashboard from Task 4 (`git rm compose/grafana/dashboards/litellm.json`).

- [ ] **Step 3: Block `/litellm/metrics` on every non-east-west Caddy site**

In `compose/tls-proxy/Caddyfile`, in the `:8447` site, the `:8092` site and inside the `handle /litellm/*` block of `:8090`, add before the `reverse_proxy` line (after the `rewrite` line in `:8447`/`:8092`, so the matcher sees the prefixed path):

```
  @litellm_metrics path /litellm/metrics /litellm/metrics/*
  respond @litellm_metrics 404
```

Validate with the Step 5 command from Task 2, then `./scripts/deploy-stack.sh tls-proxy`.

- [ ] **Step 4: Verify exposure and metric names**

```bash
for u in "http://127.0.0.1:8090/litellm/metrics" "http://127.0.0.1:8092/litellm/metrics" "http://127.0.0.1:8092/metrics"; do
  printf '%s -> ' "$u"; curl -s -o /dev/null -w '%{http_code}\n' "$u"
done
printf 'LAN :8447 -> '; curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8447/litellm/metrics
printf 'east-west  -> '; curl -s -o /dev/null -w '%{http_code}\n' "http://${HOST_INTERNAL_IP:-127.0.0.1}:4000/litellm/metrics"
grep -oE '^litellm_[a-z_]+' /tmp/claude-1000/-home-darraghog-dev-localserver-config/cdd6ea69-65bb-4e80-926d-08c9e00928cb/scratchpad/litellm-metrics.txt | sort -u | head -30
```
Expected: the four Caddy paths `404`; east-west `200`. Compare the metric names printed to those used in `compose/grafana/dashboards/litellm.json` (`litellm_proxy_total_requests_metric_total`, `litellm_proxy_failed_requests_metric_total`, `litellm_spend_metric_total`); edit the dashboard queries to the names that exist.

- [ ] **Step 5: Add the scrape job and finish**

Append to `compose/prometheus/prometheus.yml`:

```yaml
  - job_name: litellm
    metrics_path: /litellm/metrics
    static_configs:
      - targets: ['host.containers.internal:4000']
```

```bash
podman kill --signal HUP prometheus_prometheus_1
./scripts/deploy-stack.sh grafana   # only if the dashboard queries changed
./scripts/check-monitoring.sh
```
Expected: exit 0 with all nine jobs.

- [ ] **Step 6: Commit**

```bash
git add compose/litellm/config.yaml compose/tls-proxy/Caddyfile compose/prometheus/prometheus.yml compose/grafana/dashboards/litellm.json
git commit -m "Scrape LiteLLM's Prometheus metrics and hide them from the LAN and tailnet

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Registry, docs and housekeeping

**Files:**
- Modify: `architecture/model.yaml`, `README.md`, `docs/NETWORK-CONFIG.md`, `docs/BACKUP.md`
- Check: `scripts/check-updates.py`

- [ ] **Step 1: Update `gap-no-alerting`**

Replace the gap in `architecture/model.yaml`:

```yaml
  - id: gap-no-alerting
    name: Alerting limited to probes, host resources and certificates
    severity: low
    status: mitigated
    description: >
      Prometheus probes every stack and public URL, watches host disk, memory and CPU and
      the Caddy certificate, and Alertmanager posts failures to Slack #myagentchannel.
      Still uncovered: backup age (the backup scripts emit no metric), application-level
      errors in apps that expose no metrics, and a host-wide outage - the alert pipeline
      runs on the host it watches (gap-single-node), so nothing reports that the whole box
      is down. n8n and GQLDB are probe-only by decision: n8n's /metrics would be public on
      the Funnel, and GQLDB's metrics listener exposes unauthenticated /debug/pprof.
    plain_language: >
      Something now tells me when a service, a website or the disk is in trouble. It cannot
      tell me if the whole server is off, and it does not yet watch the backups.
```

(Keep the existing `affects` relationships for this id.) If Task 5's gate failed, drop the LiteLLM mention wherever it appears.

- [ ] **Step 2: README**

In `README.md`, add rows following the existing table style: stack rows for `prometheus` (8100, host-internal), `alertmanager` (8101, host-internal), `grafana` (8102, host-internal) and mention `8103` (Caddy metrics, host-internal) and the `/prometheus` and `/grafana` router mounts; update the `tls-proxy` row's "loopback-only" list only if it enumerates router paths. Run `grep -n "8098" README.md` first and match every place it appears.

- [ ] **Step 3: NETWORK-CONFIG**

Add a section "Monitoring" to `docs/NETWORK-CONFIG.md` covering: the new router mounts and why no-strip; scrape addressing (`host.containers.internal`, per-host `HOST_INTERNAL_IP`); the Caddy metrics site on `:8103`; the LiteLLM `/metrics` block on non-east-west sites; and why n8n and GQLDB are probe-only (one short paragraph each, with the reasons from the spec). Keep per-app detail out of other docs.

- [ ] **Step 4: BACKUP**

In `docs/BACKUP.md`, under "What is backed up", add one line: the Prometheus TSDB and Grafana state are deliberately excluded (metrics are disposable; Grafana is provisioned from git).

- [ ] **Step 5: check-updates sees the new images**

```bash
python3 scripts/check-updates.py 2>&1 | grep -E "prom/|grafana/" 
```
Expected: the five new images (prometheus, blackbox-exporter, node-exporter, alertmanager, grafana) are listed, and the "model drift" section shows no drift for them (the `image:` strings in `model.yaml` should match compose). Fix any drift by editing `model.yaml`.

- [ ] **Step 6: Validate and commit**

```bash
python3 scripts/arch-validate.py && echo model-ok
git add architecture/model.yaml README.md docs
git commit -m "Record monitoring in the model and docs; mark gap-no-alerting mitigated

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: End-to-end verification

**Files:** none modified unless a check fails.

- [ ] **Step 1: Full deploy from the stack order works**

```bash
./scripts/deploy.sh
./scripts/check-monitoring.sh
```
Expected: deploy completes without a post-deploy FAIL; check exits 0.

- [ ] **Step 2: Real failure reaches Slack, and recovery follows** (**posts to `#myagentchannel`**; tell the user before starting)

```bash
systemctl --user stop localserver-hello-world.service   # or: ./scripts/start-stack.sh hello-world down
sleep 420
curl -s "http://${HOST_INTERNAL_IP:-127.0.0.1}:8100/prometheus/api/v1/alerts" | python3 -c 'import json,sys; print([a["labels"]["alertname"]+" "+a["labels"]["instance"] for a in json.load(sys.stdin)["data"]["alerts"] if a["labels"]["alertname"]!="Watchdog"])'
```
Expected: `ProbeDown http://host.containers.internal:8080/` is firing; ask the user to confirm the `[FIRING] ProbeDown` message arrived in Slack. Then:

```bash
systemctl --user start localserver-hello-world.service
sleep 400
```
Expected: the `[RESOLVED]` message follows in Slack (ask the user to confirm), and `./scripts/check-monitoring.sh` exits 0 again.

- [ ] **Step 3: Exposure checks**

```bash
# reachable from a container (east-west)
for p in 8100/prometheus/-/healthy 8101/-/healthy 8102/grafana/api/health; do
  podman exec n8n_n8n_1 wget -qO- "http://host.containers.internal:$p" >/dev/null && echo "east-west OK $p" || echo "east-west FAIL $p"
done
# not reachable from the LAN or tailnet ports (run from a second machine if available)
ss -ltn | grep -E ':(8100|8101|8102|8103)\b'
```
Expected: three `east-west OK`; every listener in the `ss` output is bound to `${HOST_INTERNAL_IP}` (127.0.0.1 on beeblebox), never `0.0.0.0` or `*`. From a LAN/tailnet machine, `curl -m 3 http://<beeblebox-ip>:8100/` etc. must fail (state plainly if no second machine was available).

- [ ] **Step 4: Funnel and untouched-app checks**

```bash
tailscale funnel status > /tmp/claude-1000/-home-darraghog-dev-localserver-config/cdd6ea69-65bb-4e80-926d-08c9e00928cb/scratchpad/funnel-after.txt
git diff --stat main -- compose/n8n compose/gqldb compose/wordpress compose/tic-tac-toe compose/weather-mcp compose/hello-world compose/claude-mock-test
```
Expected: the `git diff` output is empty (no changes to those stacks). Then `diff funnel-before.txt funnel-after.txt` (both in the scratchpad, `funnel-before.txt` from Task 1 Step 0). It must be empty; the `:443` n8n entry must be identical.

- [ ] **Step 5: Final gates**

```bash
python3 scripts/arch-validate.py && echo model-ok
podman run --rm -v "$PWD/compose/prometheus:/w:ro" --entrypoint promtool docker.io/prom/prometheus:v3.5.0 test rules /w/tests/alerts.test.yml
git status --short
```
Expected: `model-ok`, `SUCCESS`, and a clean tree apart from the user's own pre-existing `.claude/settings.json` change. Report the results to the user with the Slack confirmations, and any probes that had to be dropped and why.

---

## Self-review against the spec

- **Goal 1 (Slack alert within ~5 min):** Tasks 1, 3, 7 (`for: 5m`, live stop/start test).
- **Goal 2 (host trends in Grafana):** Task 1 node-exporter, Task 4 host dashboard.
- **Goal 3 (scrape ready apps, probe the rest):** Task 1 probes, Task 2 Caddy, Task 5 LiteLLM.
- **Goal 4 (apps otherwise untouched):** Global Constraints; Task 7 Step 4 diff check.
- **Goal 5 (principles):** host-internal publishing, no LAN sites, rootless (all tasks); Task 7 Step 3.
- **Goal 6 (gap and gate):** Tasks 1/3/4 per-stack model entries, Task 6 gap update.
- **Spec open items:** LiteLLM licence (Task 5 Step 2), Caddy reachability from a container (Task 2 Step 8), Grafana sub-path (Task 4 Step 7 with fallback), Alertmanager version (Task 3 Steps 1 and 3), WSL2 vs beeblebox: **beeblebox is the target; WSL2 is not validated by this plan.** If the user wants WSL2 support, `host.containers.internal` behaviour under slirp4netns needs its own check.
- **Deliberately not covered (per spec):** application instrumentation, exporter sidecars, backup-age alerts, cAdvisor, n8n/GQLDB metrics.
