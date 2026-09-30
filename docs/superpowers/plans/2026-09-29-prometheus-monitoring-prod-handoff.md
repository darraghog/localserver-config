# Prometheus monitoring: prod handoff checklist

The monitoring stacks were built and validated offline on the laptop (promtool, amtool, `caddy validate`,
`arch-validate.py`, throwaway containers with no published ports). Nothing was deployed, no Slack message
was sent, and no production service was touched. This is what remains, to be run on the target
(beeblebox) from a laptop working tree, in this order.

Plan: `2026-09-29-prometheus-monitoring.md`. Spec: `../specs/2026-09-29-prometheus-monitoring-design.md`.

## 0. Before you deploy

- [ ] Capture the Funnel baseline on beeblebox: `ssh beeblebox tailscale funnel status > funnel-before.txt`
      (the laptop had no serve config, so no baseline exists yet).
- [ ] Put `SLACK_BOT_TOKEN` (xoxb-...) and `GRAFANA_ADMIN_PASSWORD` in the prod `.env`
      (`openssl rand -base64 24` for the password). Confirm the bot is a member of `#myagentchannel`.
- [ ] `./scripts/sudo/bootstrap-host.sh` on the host, to install the three new systemd user units
      (`localserver-prometheus`, `-alertmanager`, `-grafana`).

## 1. Deploy in this order

1. `./scripts/deploy-stack.sh litellm`, first: its config now needs `require_auth_for_metrics_endpoint: false`.
2. `./scripts/deploy-stack.sh prometheus alertmanager grafana`
3. `./scripts/deploy-stack.sh tls-proxy` (metrics site `:8103`, `/prometheus` and `/grafana` mounts, LiteLLM metrics 404s).
4. `podman kill --signal HUP prometheus_prometheus_1`

## 2. Verify

- [ ] `./scripts/check-monitoring.sh` exits 0 (all nine jobs up, no `probe_success == 0`, Watchdog firing,
      Alertmanager ready, Grafana datasource healthy).
- [ ] Probe reachability. For any probe failing from the host, decide whether it is real or a limitation:
  - the public Funnel URL `https://beeblebox.taile98462.ts.net/healthz` (hairpin may fail from the host itself);
  - `https://thelearningcto.com/`;
  - `/litellm/health/liveliness` on `:4000`, and the `:8443` TLS probe.
  Remove any probe that cannot work from the host, with a comment saying why, then HUP Prometheus.
- [ ] node-exporter sees the host: `node_filesystem_size_bytes{mountpoint="/"}` agrees with `df -B1 /`.
      The `/:/host:ro,rslave` mount is untested under rootless podman.
- [ ] Prometheus's `wget` healthcheck passes (`podman ps` shows healthy for all containers in the new stacks).
- [ ] Router: `curl http://127.0.0.1:8090/prometheus/-/healthy` returns `Prometheus Server is Healthy.`;
      the existing mounts (`cockpit tictactoe helloworld claudemock weather litellm`) return the same codes as before.
- [ ] Grafana through the router: `curl -s http://127.0.0.1:8090/grafana/login` returns 200 and the page loads
      its assets. **If the login loops or assets 404, use the plan's Task 4 Step 7 fallback** (dedicated
      tailnet port `:8099`).
- [ ] Open `https://beeblebox.taile98462.ts.net:8090/grafana/`, log in as `admin`, and confirm the Estate
      folder has Host, Probes, Caddy and LiteLLM dashboards with data. (`litellm_spend_metric_total` stays
      empty until there is LiteLLM traffic.)

## 3. Alert delivery (posts to `#myagentchannel`)

- [ ] Send a test alert:
  ```bash
  curl -sS -XPOST "http://${HOST_INTERNAL_IP:-127.0.0.1}:8101/api/v2/alerts" -H 'Content-Type: application/json' \
    -d '[{"labels":{"alertname":"MonitoringSetupTest","severity":"warn"},"annotations":{"summary":"Test alert from the Prometheus rollout - safe to ignore"}}]'
  ```
  Expect a Slack message within about 45s. No message, or a `not_in_channel`, `channel_not_found` or
  `invalid_auth` in `podman logs alertmanager_alertmanager_1`, means fix the token or channel membership.
  (This also proves Alertmanager tolerates the trailing newline in the rendered token file.)
- [ ] Real failure and recovery: stop hello-world, wait about 7 minutes, and confirm `[FIRING] ProbeDown` reaches
      Slack; start it again and confirm `[RESOLVED]` follows.
- [ ] Empty-token guard: with `SLACK_BOT_TOKEN` unset in a scratch environment, `podman-compose -f
      compose/alertmanager/compose.yaml config` errors with `SLACK_BOT_TOKEN must be set in .env`.
      (Verified offline already.)

## 4. Exposure

- [ ] `ss -ltn | grep -E ':(8100|8101|8102|8103)\b'`: every listener is on `${HOST_INTERNAL_IP}`
      (127.0.0.1 on beeblebox), never `0.0.0.0`.
- [ ] From a container: `podman exec n8n_n8n_1 wget -qO- http://host.containers.internal:8100/prometheus/-/healthy`
      (repeat for `:8101/-/healthy`, `:8102/grafana/api/health`).
- [ ] From another LAN or tailnet machine, `curl -m 3 http://<beeblebox-ip>:8100/`, `:8101`, `:8102` and `:8103`
      all fail.
- [ ] LiteLLM metrics: the Caddy paths (`http://127.0.0.1:8090/litellm/metrics`, `:8092/litellm/metrics`,
      `:8092/metrics`, `https://127.0.0.1:8447/litellm/metrics` with `-k`) return 404; the east-west
      `http://${HOST_INTERNAL_IP}:4000/litellm/metrics` returns 200. Also try encoded variants such as
      `/litellm/%6Detrics` and `/litellm//metrics` against those sites: all should 404.
- [ ] `ssh beeblebox tailscale funnel status | diff funnel-before.txt -` is empty.
- [ ] `git diff --stat` on `compose/n8n compose/gqldb compose/wordpress compose/tic-tac-toe compose/weather-mcp
      compose/hello-world compose/claude-mock-test` between the branch base and head is empty
      (already confirmed empty for this branch).

## Decisions taken during execution that you may want to revisit

- LiteLLM `/litellm/metrics` is unauthenticated east-west (`require_auth_for_metrics_endpoint: false`),
  because Prometheus has no secret-rendering path for a bearer token and Caddy hides it from the LAN and
  tailnet. Alternative: a `bearer_token` scrape using the master key.
- Grafana is scraped at `/grafana/metrics` (verified offline: root `/metrics` 301-redirects to it).
- The Windows LAN-port script will open a firewall rule and portproxy for `:8103` to `[::1]:8103` where
  nothing listens (same as `:8090`, `:8092`, `:8098`). Harmless, and noted in `docs/NETWORK-CONFIG.md`.
- WSL2 (slirp4netns) is not validated; the plan targets beeblebox only.
