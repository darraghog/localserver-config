# Prometheus monitoring: prod handoff checklist

The monitoring stacks were built and validated offline on the laptop (promtool, amtool, `caddy validate`,
`arch-validate.py`, throwaway containers with no published ports). Nothing was deployed, no Slack message
was sent, and no production service was touched. This is what remains, to be run on the target
(beeblebox) from a laptop working tree, in this order.

Plan: `2026-09-29-prometheus-monitoring.md`. Spec: `../specs/2026-09-29-prometheus-monitoring-design.md`.

## 0. Before you deploy

Everything below runs from the laptop working tree unless it says `ssh <host>`. `<host>` is the prod
target (beeblebox).

- [ ] Capture the Funnel baseline: `ssh <host> tailscale funnel status > funnel-before.txt`
      (the laptop had no serve config, so no baseline exists yet).
- [ ] Add `SLACK_BOT_TOKEN` (xoxb-...) and `GRAFANA_ADMIN_PASSWORD` (`openssl rand -base64 24`) to
      **`envs/prod.env` on the laptop**, not to the server's `.env`. `scripts/deploy-service.sh` and
      `scripts/deploy-to-server.sh` copy `envs/<env>.env` over the target's `.env` on every run, so an edit
      made on the server is overwritten. Confirm the bot is a member of `#myagentchannel`.
- [ ] A full `scripts/deploy.sh` runs `set -e` over `compose/stack-order` and aborts at alertmanager when
      either variable is missing from the env file in use, so grafana and tls-proxy never deploy. The same
      applies to `envs/local.env` when the laptop runs a full `deploy.sh`: add both variables there too, or
      deploy stacks individually.

## 1. Deploy in this order

1. LiteLLM first, so it has `require_auth_for_metrics_endpoint: false`. The repo's litellm-specific script
   pushes the config and restarts the container without pulling an image or syncing:
   `./scripts/deploy-litellm.sh --config-only prod <host>`
2. Get the repo onto the host, then install the new systemd user units from the synced tree (needs sudo on
   the host, so it must run after the sync):
   ```bash
   rsync -avz --delete --exclude='.git' --exclude='certs/' --exclude='.env' --exclude='envs/' \
     --exclude='cloudflared/config.yml' --filter='P certs/' --filter='P cloudflared/config.yml' \
     ./ <host>:~/localserver-config/
   ssh -t <host> '~/localserver-config/scripts/sudo/bootstrap-host.sh'
   ```
   (This is the same rsync `deploy-service.sh` performs; deploying any stack with it also syncs.)
3. Prometheus and Grafana first: `./scripts/deploy-service.sh prod <host> prometheus grafana`
   (also copies `envs/prod.env` to the host's `.env`).
4. Check before Alertmanager goes live with the real token, so hairpin/Funnel probe failures found here do
   not page on first start:
   `ssh <host> 'cd ~/localserver-config && CHECK_SKIP_JOBS="alertmanager" ./scripts/check-monitoring.sh'`
   Triage every probe failure (section 2) before continuing. Prometheus already has Alertmanager as a
   configured target, so pages start the moment Alertmanager comes up.
5. `./scripts/deploy-service.sh prod <host> alertmanager`
6. `./scripts/deploy-service.sh prod <host> tls-proxy` (metrics site `:8103`, `/prometheus` and `/grafana`
   mounts, LiteLLM metrics 404s).
7. Only if `compose/prometheus/prometheus.yml` (or blackbox.yml) changed after Prometheus started, for
   example after removing a probe in step 4: `ssh <host> podman kill --signal HUP prometheus_prometheus_1`.
   Not needed on a first start.

## 2. Verify

Run on the host: `ssh <host>` first, then `cd ~/localserver-config`.

- [ ] `./scripts/check-monitoring.sh` exits 0 (all ten scrape jobs up, no `probe_success == 0`, tls-cert probe
      succeeding, Watchdog firing, Alertmanager ready, Grafana datasource healthy).
- [ ] Probe reachability. For any probe failing from the host, decide whether it is real or a limitation:
  - the public Funnel URL `https://beeblebox.taile98462.ts.net/healthz` (hairpin may fail from the host itself);
  - `https://thelearningcto.com/`;
  - `/litellm/health/liveliness` on `:4000`, and the `:8443` TLS probe.
  Remove any probe that cannot work from the host, with a comment saying why, then HUP Prometheus (step 7).
- [ ] TLS-expiry probe target answers with the probe's SNI (on the host):
      `openssl s_client -connect 127.0.0.1:8443 -servername host.containers.internal </dev/null 2>/dev/null | openssl x509 -noout -enddate`
      If the probe fails because Caddy rejects the SNI `host.containers.internal`, set `tls_config.server_name`
      in `compose/prometheus/blackbox.yml`'s `tls_expiry` module to a name in the certificate's SANs (the
      host's `hostname`, `localhost`, `127.0.0.1` and any `DEPLOY_CERT_EXTRA_SANS`; see
      `scripts/bootstrap-tls.sh` / `setup-certs.sh`), redeploy prometheus and HUP it.
- [ ] node-exporter sees the host: `node_filesystem_size_bytes{mountpoint="/"}` agrees with `df -B1 /`.
      The `/:/host:ro,rslave` mount is untested under rootless podman. (The host dashboard has no network
      panel: node-exporter runs in its own network namespace and would show container traffic.)
- [ ] Prometheus's `wget` healthcheck passes (`podman ps` shows healthy for all containers in the new stacks).
- [ ] Router: `curl http://127.0.0.1:8090/prometheus/-/healthy` returns `Prometheus Server is Healthy.`;
      the existing mounts (`cockpit tictactoe helloworld claudemock weather litellm`) return the same codes as before.
- [ ] Grafana through the router: `curl -s http://127.0.0.1:8090/grafana/login` returns 200 and the page loads
      its assets. **If the login loops or assets 404, use the plan's Task 4 Step 7 fallback** (dedicated
      tailnet port `:8099`).
- [ ] Open `https://beeblebox.taile98462.ts.net:8090/grafana/`, log in as `admin`, and confirm the Estate
      folder has Host, Probes, Caddy and LiteLLM dashboards with data. (`litellm_spend_metric_total` stays
      empty until there is LiteLLM traffic.)
- [ ] After Alertmanager and Grafana are up, re-run the full `./scripts/check-monitoring.sh` (no skips) on the host.

## 3. Alert delivery (posts to `#myagentchannel`)

- [ ] Send a test alert:
  ```bash
  # on the host: ssh <host>
  curl -sS -XPOST "http://${HOST_INTERNAL_IP:-127.0.0.1}:8101/api/v2/alerts" -H 'Content-Type: application/json' \
    -d '[{"labels":{"alertname":"MonitoringSetupTest","severity":"warn"},"annotations":{"summary":"Test alert from the Prometheus rollout - safe to ignore"}}]'
  ```
  Expect a Slack message within about 45s. No message, or a `not_in_channel`, `channel_not_found` or
  `invalid_auth` in `ssh <host> podman logs alertmanager_alertmanager_1`, means fix the token or channel membership.
  (This also proves Alertmanager tolerates the trailing newline in the rendered token file.)
- [ ] Real failure and recovery: stop hello-world, wait about 7 minutes, and confirm `[FIRING] ProbeDown` reaches
      Slack; start it again and confirm `[RESOLVED]` follows.
- [ ] Empty-token guard: with `SLACK_BOT_TOKEN` unset in a scratch environment, `podman-compose -f
      compose/alertmanager/compose.yaml config` errors with `SLACK_BOT_TOKEN must be set in .env`.
      (Verified offline already.)

## 4. Exposure

- [ ] `ssh <host> "ss -ltn" | grep -E ':(8100|8101|8102|8103)\b'`: every listener is on `${HOST_INTERNAL_IP}`
      (127.0.0.1 on beeblebox), never `0.0.0.0`.
- [ ] From a container (`ssh <host>`): `podman exec n8n_n8n_1 wget -qO- http://host.containers.internal:8100/prometheus/-/healthy`
      (repeat for `:8101/-/healthy`, `:8102/grafana/api/health`).
- [ ] From another LAN or tailnet machine, `curl -m 3 http://<beeblebox-ip>:8100/`, `:8101`, `:8102` and `:8103`
      all fail (run from the laptop or another machine, not the host).
- [ ] LiteLLM metrics (on the host): the Caddy paths (`http://127.0.0.1:8090/litellm/metrics`, `:8092/litellm/metrics`,
      `:8092/metrics`, `https://127.0.0.1:8447/litellm/metrics` with `-k`) return 404; the east-west
      `http://${HOST_INTERNAL_IP}:4000/litellm/metrics` returns 200. Also try encoded variants such as
      `/litellm/%6Detrics` and `/litellm//metrics` against those sites: all should 404.
- [ ] `ssh <host> tailscale funnel status | diff funnel-before.txt -` is empty.
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
