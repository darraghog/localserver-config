#!/usr/bin/env bash
# provisioning-sync.sh (infra repo: scripts/provisioning-sync.sh) - owner wrapper. Pushes the
# provisioning YAML as deployed (the working tree shipped by deploy-service.sh, committed or not)
# into the graph by running `python -m homelab_arch provisioning-sync` inside the app container
# on the server, over ssh.
#
# Source of truth: homelab-arch deploy/infra/provisioning-sync.sh (copied byte-identical).
#
# usage: provisioning-sync.sh [--check]
#   --check  read-only difference report; needs no terminal, never prompts.
#   (none)   writes the graph; needs a terminal on stdin AND stdout for the approval prompt.
# No other argument is accepted. Every word of the ssh command line is fixed apart from the two
# validated environment words, because ssh joins its arguments into one string for the remote shell.
#
# Environment: HLA_SSH_HOST (default beeblebox), HLA_CONTAINER (default homelab-arch_app_1).
# No token or password is read or forwarded by this wrapper.
#
# Exit codes:
#   0-4        from provisioning-sync itself (0 in sync/done, 1 refused, 2 usage/config/guard
#              refusal, 3 graph error part-way, 4 --check found differences)
#   2          also: this wrapper refused its arguments, names, or has no terminal
#   255        from ssh (connection or auth failure)
#   125-127    from podman (exec failed / command not runnable / not found)
set -euo pipefail
shopt -u nocasematch

DIR=/infra/architecture/provisioning

usage() {
    echo "usage: provisioning-sync.sh [--check]" >&2
    exit 2
}

die() {
    echo "provisioning-sync.sh: $1" >&2
    exit 2
}

legend() {
    cat >&2 <<LEGEND
provisioning-sync exit codes:
  0 in sync / done    1 refused    2 usage, config or guard refusal
  3 graph error part-way (re-running converges)    4 --check found differences
A write run asks you to type '<graph> <12-hex digest>'. This wrapper does not print the digest;
compute it inside the container: python -m homelab_arch input-digest $DIR
LEGEND
}

# Use "-" (not ":-") so an empty value is refused instead of silently defaulted.
HOST=${HLA_SSH_HOST-beeblebox}
C=${HLA_CONTAINER-homelab-arch_app_1}
name_re='^[A-Za-z0-9][A-Za-z0-9._-]{0,252}$'
[[ $HOST =~ $name_re && $C =~ $name_re ]] || die "bad host/container name"

if (($# == 0)); then
    [[ -t 0 && -t 1 ]] || die "a write run needs an interactive terminal (use --check for a report)"
    legend
    exec ssh -t -- "$HOST" podman exec -it -e HLA_ALLOW_GRAPH_WRITES=homelab_arch "$C" \
        python -m homelab_arch provisioning-sync "$DIR"
elif (($# == 1)) && [[ $1 == --check ]]; then
    legend
    exec ssh -n -o BatchMode=yes -- "$HOST" podman exec "$C" \
        python -m homelab_arch provisioning-sync "$DIR" --check
else
    usage
fi
