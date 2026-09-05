# Parse compose/tls-proxy/Caddyfile: print "https_port backend_port backend_host" per site
# with a reverse_proxy to an IPv4 backend.
#
# The backend host is NOT always 127.0.0.1. Under p-open-east-west (architecture/model.yaml)
# container stacks publish on the host-internal address, so their Caddy targets read
# 10.255.255.254:<port>; host services (cockpit) and stacks still on 0.0.0.0 (hello-world,
# n8n) keep 127.0.0.1. Callers need the host as well as the port to probe the backend.
BEGIN { site_https = ""; in_site = 0 }
/^[[:space:]]*:[0-9]+[[:space:]]*\{/ {
  if (match($0, /^[[:space:]]*:[0-9]+/)) {
    tok = substr($0, RSTART, RLENGTH)
    gsub(/[^0-9]/, "", tok)
    site_https = tok
    in_site = 1
  }
  next
}
# Migrated backends read "{env.HOST_INTERNAL_IP}:PORT" (per-host address, resolved by Caddy
# at load time). Emit the resolved value from the environment so callers can probe them.
in_site && /^[[:space:]]*reverse_proxy[[:space:]]+\{env\.HOST_INTERNAL_IP\}:[0-9]+/ {
  if (match($0, /\{env\.HOST_INTERNAL_IP\}:[0-9]+/)) {
    hostport = substr($0, RSTART, RLENGTH)
    sub(/^\{env\.HOST_INTERNAL_IP\}:/, "", hostport)
    hi = ENVIRON["HOST_INTERNAL_IP"]
    if (hi == "") hi = "127.0.0.1"
    if (site_https != "" && hostport ~ /^[0-9]+$/) print site_https, hostport, hi
  }
  next
}
in_site && /^[[:space:]]*reverse_proxy[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/ {
  if (match($0, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/)) {
    hostport = substr($0, RSTART, RLENGTH)
    split(hostport, hp, ":")
    if (site_https != "" && hp[2] ~ /^[0-9]+$/) print site_https, hp[2], hp[1]
  }
  next
}
in_site && /^[[:space:]]*\}/ {
  in_site = 0
  site_https = ""
  next
}
