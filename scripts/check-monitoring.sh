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
    try:
        return json.load(urllib.request.urlopen(prom + path, timeout=10))
    except OSError as e:
        print(f"FAIL cannot query prometheus: {e}", file=sys.stderr); sys.exit(1)

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
