# Parse compose/tls-proxy/Caddyfile: print "https_port backend_port" per site with
# reverse_proxy 127.0.0.1:<backend>.
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
in_site && /^[[:space:]]*reverse_proxy[[:space:]]+127\.0\.0\.1:/ {
  if (match($0, /127\.0\.0\.1:[0-9]+/)) {
    rest = substr($0, RSTART, RLENGTH)
    sub(/^127\.0\.0\.1:/, "", rest)
    if (site_https != "" && rest ~ /^[0-9]+$/) print site_https, rest
  }
  next
}
in_site && /^[[:space:]]*\}/ {
  in_site = 0
  site_https = ""
  next
}
