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

python3 - "$PROM" "${CHECK_SKIP_JOBS:-}" "$REPO_ROOT/compose/grafana/dashboards" <<'PY' || fail=1
import glob, json, sys, time, urllib.request, urllib.parse

prom, skip = sys.argv[1], set(sys.argv[2].split())
dash_dir = sys.argv[3]
def get(path):
    try:
        return json.load(urllib.request.urlopen(prom + path, timeout=10))
    except OSError as e:
        print(f"FAIL cannot query prometheus: {e}", file=sys.stderr); sys.exit(1)

expected = {"prometheus", "node", "probe-http", "probe-http-noredirect", "probe-tcp", "tls-cert",
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
if "tls-cert" not in skip:
    res = get("/api/v1/query?" + urllib.parse.urlencode({"query": 'probe_success{job="tls-cert"} == 1'}))["data"]["result"]
    ok_inst = {r["metric"].get("instance") for r in res}
    allp = get("/api/v1/query?" + urllib.parse.urlencode({"query": 'probe_success{job="tls-cert"}'}))["data"]["result"]
    for r in allp:
        if r["metric"].get("instance") not in ok_inst:
            print(f"FAIL tls-cert probe failing: {r['metric'].get('instance')}", file=sys.stderr); rc = 1
res = get("/api/v1/query?" + urllib.parse.urlencode({"query": 'ALERTS{alertname="Watchdog",alertstate="firing"}'}))["data"]["result"]
if not res:
    print("FAIL Watchdog is not firing (rules not loaded?)", file=sys.stderr); rc = 1
# Metric identity: no series, and no dashboard query result, may lack both service and entity.
# Recent window only: series written before the labels existed stay in the TSDB until retention expires.
anon = get("/api/v1/series?" + urllib.parse.urlencode({"match[]": '{__name__=~".+",service="",entity=""}', "start": time.time() - 300}))["data"]
for s_ in anon[:10]:
    print(f"FAIL series with no service/entity label: {s_}", file=sys.stderr); rc = 1
if len(anon) > 10:
    print(f"FAIL ... and {len(anon) - 10} more series with no identity", file=sys.stderr)
for path in sorted(glob.glob(dash_dir + "/*.json")):
    for panel in json.load(open(path)).get("panels", []):
        for tgt in panel.get("targets", []):
            for r in get("/api/v1/query?" + urllib.parse.urlencode({"query": tgt["expr"]}))["data"]["result"]:
                m = r["metric"]
                if not (m.get("service") or m.get("entity")):
                    print(f"FAIL dashboard {path.rsplit('/', 1)[-1]} panel {panel['title']!r}: result lacks service/entity: {m}", file=sys.stderr); rc = 1
                    break
if rc == 0:
    print("OK   all expected targets up, no failing probes, Watchdog firing, every series and dashboard result has an identity")
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
