# Prometheus monitoring: metrics, dashboards and Slack alerting

*Design, 2026-09-29. Status: draft, pending review.*

## Problem

`gap-no-alerting` in `architecture/model.yaml` records that nothing reports failure. A
stopped stack, a failed probe target or a full disk is found by looking. There is also no
history: no way to see whether a service was flapping, or how a host resource trended.

## Goal and success criteria

Add Prometheus, Alertmanager and Grafana as new stacks so that:

1. A stack that stops, or a public/internal endpoint that stops answering, raises a message
   in Slack `#myagentchannel` within about five minutes.
2. Host disk, memory and CPU trends are visible in Grafana.
3. Applications that already speak Prometheus are scraped; the rest are covered by probes.
4. Existing applications are otherwise untouched.
5. The new stacks obey the estate's principles: tailnet-only exposure, `HOST_INTERNAL_IP`
   publishing, rootless, and everything reproducible from git plus `.env`.
6. `gap-no-alerting` is closed or narrowed in `model.yaml`, and the deploy gate passes.

## Non-goals

- Instrumenting application code (tic-tac-toe, weather-mcp) or adding exporter sidecars to
  WordPress, MariaDB or either Postgres. **Decided: do not change applications that are not
  already Prometheus-ready.**
- Publishing anything to the public Funnel or Cloudflare Tunnel.
- Backup-age alerting (needs a metric the backup scripts do not emit).
- A cAdvisor/podman per-container exporter. Rootless podman makes it fiddly; deferred.
- High availability or long-term storage. Metrics are disposable.

## Decisions taken

| Decision | Choice | Why |
|---|---|---|
| Grafana | In scope | Requested. |
| Alert channel | Slack `#myagentchannel`, direct from Alertmanager | Reuses the bot token and `chat.postMessage` pattern of the `slack-publish-myagentchannel` skill. The alert path must not depend on something it monitors, which rules out n8n. |
| Existing apps | Config-only changes to apps already Prometheus-ready | Requested. |
| n8n | **No metrics.** Probe `/healthz` and the public URL only | The public Funnel `:443` forwards straight to `127.0.0.1:5678`, bypassing Caddy, and n8n has no separate metrics port. `N8N_METRICS=true` would publish `/metrics` unauthenticated to the internet, violating `p-tiered-exposure`. Repointing the Funnel would break the "`:443` entry stays byte-identical" rule. |
| GQLDB | **Metrics stay off.** Probe TCP `:60061` and the console only | `GQLDB_METRICS_ENABLED` is deliberately false: the listener is unauthenticated and mounts `/debug/pprof`, which east-west openness would expose to every container. |
| TSDB backup | Not backed up | Disposable. Grafana state is provisioned from git, so it holds nothing worth backing up. |

## Architecture

Three new stacks under `compose/`, listed in `compose/stack-order` before `tls-proxy`,
scaffolded with `scripts/add-service.sh` (which also produces the systemd user unit).

### `prometheus` stack

Containers: `prometheus`, `blackbox` (blackbox_exporter), `node-exporter`.

- Prometheus config and rule files live in the repo (`compose/prometheus/`) and are
  bind-mounted read-only. TSDB on a named volume, with explicit retention (default 15d) and
  a size cap.
- Published as `${HOST_INTERNAL_IP:?...}:<port>`, per `p-open-east-west`. Ports are
  allocated in the spec's implementation plan from the free range and recorded in
  `.env.example` and the Caddyfile header.
- Tailnet exposure: mounted on the `:8090` path router at `/prometheus`. It must run with
  `--web.external-url` and `--web.route-prefix` set for that prefix, and is **no-strip**
  (same pattern as litellm), avoiding the `handle_path` footgun in `NETWORK-CONFIG.md`.
- `node-exporter` publishes nothing. Prometheus reaches it over the stack's own network.
  Under rootless podman it sees the container's view of `/proc` and `/sys` unless the host
  root is mounted read-only with `--path.rootfs`; the plan must validate that its disk
  figures match the host's.
- `blackbox` likewise publishes nothing.

### `alertmanager` stack

- Config in git; the Slack token is never committed. A deploy step renders the token from
  `.env` (`SLACK_BOT_TOKEN`) into a file (mode 0600) that the config references via
  `http_config.authorization.credentials_file`, with `api_url:
  https://slack.com/api/chat.postMessage` and `channel: '#myagentchannel'`.
- Published on `${HOST_INTERNAL_IP}` only, so Prometheus can reach it. No Caddy site and no
  tailnet path: its UI is not needed. Silences, if required, are made with `amtool` or by
  temporarily forwarding a port.
- Requires Alertmanager 0.28 or later for bot-token Slack auth. The plan must confirm the
  pinned version supports it; if not, fall back to the Slack incoming-webhook form and
  record why.
- Grouped, with a repeat interval long enough not to spam (start at 4h) and a resolved
  notification.

### `grafana` stack

- Datasource (Prometheus) and dashboards provisioned from files in the repo; nothing is
  configured by hand in the UI, per `p-reproducible`. Admin password from `.env`
  (`GRAFANA_ADMIN_PASSWORD`, required with `:?`).
- Tailnet-only. Mount is decided in the plan by testing sub-path support:
  `GF_SERVER_ROOT_URL` with `GF_SERVER_SERVE_FROM_SUB_PATH=true` under `/grafana` on
  `:8090` if it works cleanly; otherwise a dedicated root-mounted tailnet port, as litellm
  originally needed.
- Initial dashboards: host (node_exporter), probe status/latency (blackbox), Caddy, LiteLLM.

## What gets scraped

All targets are addressed as `host.containers.internal:<port>`, per the east-west docs.

**Metrics endpoints (scraped):**

| Target | Change to the target | Notes |
|---|---|---|
| Prometheus, Alertmanager, Grafana | none | Self-metrics. |
| node-exporter | none (part of the new stack) | Host metrics. |
| Caddy | Enable the `metrics` global option and expose the admin/metrics listener to loopback only, in `compose/tls-proxy/Caddyfile`. | Caddy runs in host network mode, so the listener must bind loopback and be reached through the same host-loopback mapping. Plan must verify reachability from a container. |
| LiteLLM | Add the Prometheus callback to `litellm_settings` in `compose/litellm/config.yaml`. | **Must be verified** on `main-stable` without an enterprise licence. Path is expected to be `/litellm/metrics` because of `SERVER_ROOT_PATH`. If the callback is licence-gated, LiteLLM drops to probe-only and this spec is amended. |

**Probes only (no change to the application):**

| Probe | Method |
|---|---|
| tic-tac-toe | HTTP `/health` |
| weather-mcp | HTTP `/health` |
| LiteLLM | HTTP `/litellm/health/liveliness` (in addition to metrics) |
| n8n | HTTP `/healthz` on the host port and on the public URL |
| WordPress / blog | HTTP on the backend and on `thelearningcto.com` |
| hello-world, claude-mock-test | HTTP 200 |
| GQLDB | TCP connect `:60061`; HTTP on the manager console |
| TLS certificates | blackbox TLS probe of the Caddy sites, for expiry |

Public-URL probes exit the house and come back in, so they test the real path (Funnel or
Cloudflare Tunnel). The plan must confirm the host can reach its own public names; the
memory note on WSL2 self-connection suggests this may not hold on the laptop, but should on
beeblebox.

## Alert rules (initial)

- `ProbeDown`: any probe failing for 5m (severity page).
- `EndpointSlow`: probe duration over a threshold for 10m (severity warn).
- `CertExpiringSoon`: under 14 days (warn), under 3 days (page).
- `HostDiskFilling`: under 15% free, and predicted full within 24h.
- `HostMemoryHigh`, `HostCpuHigh`: sustained thresholds.
- `TargetDown`: any scraped target down for 5m.
- `Watchdog`: an always-firing alert, routed to nowhere, used only to prove the pipeline
  evaluates rules.

Rules live in git and are checked with `promtool check rules` in the pre-commit hook or
deploy script.

## Repository obligations

The deploy gate refuses on drift, so these are part of the work, not follow-ups.

- `architecture/model.yaml`: `ApplicationComponent` entries for prometheus, alertmanager,
  grafana; `ApplicationService` entries for the tailnet endpoints; nodes/relationships for
  Slack as an external dependency; update `gap-no-alerting` (status and description).
  Validate with `python3 scripts/arch-validate.py`.
- `.env.example`: `SLACK_BOT_TOKEN`, `GRAFANA_ADMIN_PASSWORD`, any new port variables.
- `compose/tls-proxy/Caddyfile`: routes for prometheus and grafana; header comment updated.
- `scripts/lib/post-deploy-caddy.sh`: health probe cases for the new stacks.
- `compose/windows-lan-extra-ports.txt` and the WSL port script inputs, if new host-published
  ports need LAN forwarding (they should not, being host-internal).
- `docs/NETWORK-CONFIG.md`: the tailnet routes and the note on why n8n and GQLDB are
  probe-only. Per-app detail stays out of `docs/`, per the registry rule.
- `scripts/check-updates.py`: new images must be visible to it.
- `docs/BACKUP.md`: note that the monitoring TSDB is deliberately excluded.

## Risks and open items

1. **LiteLLM callback licensing** (gates the LiteLLM scrape; fallback is probe-only).
2. **Caddy metrics reachability** from a container, given host networking.
3. **Grafana sub-path serving** under the no-strip tailnet router.
4. **Alertmanager version** supporting bot-token Slack auth.
5. **WSL2 vs beeblebox**: the slirp4netns address behaviour differs from pasta; the plan
   validates scraping on both, but beeblebox is the target.
6. **Alert pipeline hosted on the monitored host**: a host-wide outage silences the alerts
   about it. Accepted, consistent with `gap-single-node`. An external dead-man's-switch is a
   possible later addition.
7. **Slack token blast radius**: the bot token can post to any channel it belongs to. It is
   stored only in `.env` (same posture as other provider keys, `gap-no-secret-rotation`).

## Verification

- `promtool check config` and `check rules`; `amtool check-config`.
- All Prometheus targets `up` on beeblebox; every probe target returns expected status.
- Deliberately stop a low-value stack (hello-world) and confirm `ProbeDown` reaches
  `#myagentchannel` and the resolved message follows on restart.
- Confirm from a container that Prometheus, Alertmanager and Grafana are reachable
  east-west, and from the LAN that they are not.
- `tailscale funnel status` diffed before and after: the `:443` n8n entry must be identical.
- Confirm n8n and GQLDB compose files are unchanged in the diff.
- `python3 scripts/arch-validate.py` passes.
