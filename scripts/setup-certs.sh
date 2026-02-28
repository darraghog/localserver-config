#!/usr/bin/env bash
# Generate TLS certificates (separate from deploy). Run once per host before deploying tls-proxy.
# Usage: ./scripts/setup-certs.sh [hostname1] [hostname2] ...
# Delegates to bootstrap-tls.sh

exec "$(dirname "$0")/bootstrap-tls.sh" "$@"
