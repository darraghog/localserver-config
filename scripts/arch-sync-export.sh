#!/usr/bin/env bash
# scripts/arch-sync-export.sh (infra repo): the daily publish of approved graph changes, run on
# the owner's WORKSTATION (not the server) from localserver-homelab-arch-export-sync.service
# (daily 09:00, via its timer).
#
# Source of truth: homelab-arch deploy/infra/arch-sync-export.sh.
#
# Direction: graph -> git is PUBLISHED (approved proposals already changed the graph; this
# commits the re-export and deploys it). git -> graph drift (committed provisioning YAML vs the
# graph) is only REPORTED: provisioning-sync is only ever run with --check.
#
# Steps:
#   1. flock ${XDG_RUNTIME_DIR:-/tmp}/arch-sync-export.lock; held by another run -> exit 0.
#   2. Refuse (exit 2) unless on main, with a clean `git status --porcelain` and no local commit
#      ahead of @{u} (unpushed commits are never published by this script: their net diff could
#      hide an intermediate commit, and they never went through arch-check here); then
#      `git pull --ff-only`.
#   3. scripts/arch-export.sh. No change -> "export unchanged", go to 7.
#   4. Only architecture/{export.json,model.yaml,metamodel.yaml,overview.html} may change, and
#      scripts/arch-check.sh must pass; otherwise architecture/ is restored and the run fails.
#   5. Commit those files (never --no-verify): "architecture: export after <ids>", the body
#      listing `id actor summary` of each applied proposal decided after the last commit that
#      touched architecture/export.json; "architecture: export refresh (graph changed)" when the
#      proposals cannot be read or none qualify. A refusing hook restores the files.
#   6. git push origin main; then, only if the tree is still clean and HEAD equals @{u} (deploy
#      ships the working tree), scripts/deploy-service.sh prod "$HOST" homelab-arch. A failure
#      keeps the commit and says whether it was pushed.
#   7. Freshness: start localserver-homelab-arch-export-check.service on the server (a oneshot
#      start blocks, so its exit status counts) and require LoadState=loaded and Result=success.
#      A failure is exit 1, but step 8 still runs.
#   8. Drift report: provisioning-sync /infra/architecture/provisioning --check in the container.
#      Drift is exit 3; a check that cannot run (ssh, container, config) is exit 1.
#
# Environment:
#   HLA_SSH_HOST   ssh host (default beeblebox); must match ^[A-Za-z0-9._-]+$, not start with -
#   HLA_CONTAINER  app container (default homelab-arch_app_1); same rule
#   DEPLOY_SSH_DEST, DEPLOY_SSH_PORT, DEPLOY_REMOTE_PATH  unset at start: the deploy always goes
#                  to $HLA_SSH_HOST with deploy-service.sh's defaults
# Every ssh command line is a fixed constant apart from those two validated words, and always
# carries -o BatchMode=yes and `--`; SSH_ASKPASS=/bin/false with SSH_ASKPASS_REQUIRE=force is
# exported for the whole run, so no password or passphrase prompt can be answered. Neither stops
# a Tailscale SSH check-mode wait (the server side holds the session open): the `timeout`
# wrappers bound that and every other hang (each ssh 2m, git pull/push 2m, arch-export 15m,
# arch-check 15m, git commit with its hook 15m, deploy-service 35m); a timeout is exit 1 with a
# TIMED OUT message, said only when `timeout` itself fired (a command's own 124/137 is not one).
# ssh uses the user's normal ~/.ssh config and keys; under the systemd user unit an agent is only
# reachable when SSH_AUTH_SOCK is set (see the unit's optional Environment= line). origin is
# HTTPS (through gh's credential helper), so git push/pull do not use these ssh settings.
#
# Exit codes:
#   0  done, or nothing to do (including: another run holds the lock)
#   1  a step failed (pull, export, path/check refusal, commit hook, push, deploy, freshness,
#      a drift check that could not run, any timeout)
#   2  refused: checkout not on main, not clean, local commits not pushed, or a bad env word
#   3  everything else succeeded but provisioning drift was found (the DRIFT lines say what)
set -euo pipefail
umask 022

log() { printf '[arch-sync] %s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"; }
err() { log "$@" >&2; }
refuse() { err "REFUSED: $*"; exit 2; }
fail() { err "FAILED: $*"; exit 1; }

unset DEPLOY_SSH_DEST DEPLOY_SSH_PORT DEPLOY_REMOTE_PATH
export SSH_ASKPASS=/bin/false SSH_ASKPASS_REQUIRE=force

HOST=${HLA_SSH_HOST-beeblebox}
C=${HLA_CONTAINER-homelab-arch_app_1}
re='^[A-Za-z0-9._-]+$'
[[ $HOST =~ $re && $HOST != -* ]] || refuse "HLA_SSH_HOST must match ^[A-Za-z0-9._-]+\$ and not start with '-'"
[[ $C =~ $re && $C != -* ]] || refuse "HLA_CONTAINER must match ^[A-Za-z0-9._-]+\$ and not start with '-'"

PROPOSALS_URL='http://127.0.0.1:8104/api/proposals?status=applied&limit=200'
CHECK_UNIT=localserver-homelab-arch-export-check.service
FILES=(architecture/export.json architecture/model.yaml architecture/metamodel.yaml architecture/overview.html)

# Run "$@" under timeout; $1 = limit, $2 = what (for the message); returns the command's status.
# The command runs in a small bash that records its exit status in a marker file when it ends on
# its own. A 124/137 from `timeout` with no marker means `timeout` fired (it signals the whole
# group, so the bash dies too); with a marker it is the command's own status. A real timeout is
# said here and leaves $RUNTMP/timed-out behind (visible across $(...) subshells).
bounded() {
    local limit=$1 what=$2 rc=0 mark
    shift 2
    mark=$(mktemp "$RUNTMP/rc.XXXXXX") || fail "cannot create a marker file"
    timeout -k 10s "$limit" bash -c '"$@"; r=$?; echo "$r" >"$0"; exit "$r"' "$mark" "$@" || rc=$?
    if ((rc == 124 || rc == 137)) && [[ ! -s $mark ]]; then
        err "TIMED OUT: $what after $limit"
        : >"$RUNTMP/timed-out"
    fi
    rm -f -- "$mark"
    return "$rc"
}
# One fixed ssh prefix. -n: no remote command may read this script's stdin.
rssh() { bounded 2m "ssh to $HOST" ssh -n -o BatchMode=yes -o ConnectTimeout=30 -- "$HOST" "$@"; }

# --- 1. lock --------------------------------------------------------------------------------
LOCK="${XDG_RUNTIME_DIR:-/tmp}/arch-sync-export.lock"
exec 9>>"$LOCK" || fail "cannot open the lock file $LOCK"
if ! flock -n 9; then
    log "another run is in progress (lock $LOCK held); nothing done"
    exit 0
fi

RUNTMP=$(mktemp -d) || fail "cannot create a temp dir"
trap 'rm -rf -- "$RUNTMP"' EXIT

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || fail "cannot locate the script"
ROOT=$(dirname -- "$script_dir")
cd -- "$ROOT" || fail "cannot cd to $ROOT"
export GIT_TERMINAL_PROMPT=0

restore() {
    git checkout -q HEAD -- architecture/ || err "could not restore architecture/ (git checkout)"
    git clean -fdq -- architecture/ || err "could not remove untracked files in architecture/"
}

outside_paths() { # stdin: paths; prints each one that is not one of FILES
    local p f ok
    while IFS= read -r p; do
        [[ -n $p ]] || continue
        ok=0
        for f in "${FILES[@]}"; do [[ $p == "$f" ]] && ok=1; done
        ((ok)) || printf '%s\n' "$p"
    done
    return 0
}

# --- 2. checkout state, pull ----------------------------------------------------------------
branch=$(git symbolic-ref --short -q HEAD) || branch=""
[[ $branch == main ]] || refuse "the checkout is on '${branch:-a detached HEAD}', not main"
dirty=$(git status --porcelain) || fail "git status failed"
[[ -z $dirty ]] || refuse "the checkout is not clean (git status --porcelain):"$'\n'"$dirty"
ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null) || refuse "main has no upstream (@{u}) to compare with"
((ahead == 0)) || refuse "local main has unpushed commits; push or reset them first ($ahead ahead of @{u})"
log "pulling (git pull --ff-only)"
bounded 2m "git pull" git pull -q --ff-only || fail "git pull --ff-only failed"

publish=0

# --- 3. export ------------------------------------------------------------------------------
log "running scripts/arch-export.sh"
if ! bounded 15m "scripts/arch-export.sh" scripts/arch-export.sh; then
    restore
    fail "scripts/arch-export.sh failed; architecture/ restored"
fi
status=$(git status --porcelain --untracked-files=all) || fail "git status failed"
if [[ -z $status ]]; then
    log "export unchanged"
else
    # --- 4. what changed, then the checks ---------------------------------------------------
    changed=$(cut -c4- <<<"$status")
    bad=$(outside_paths <<<"$changed")
    if [[ -n $bad ]]; then
        restore
        err "the export changed paths outside the four export files:"
        while IFS= read -r p; do err "  $p"; done <<<"$bad"
        fail "nothing committed; architecture/ restored"
    fi
    log "running scripts/arch-check.sh"
    if ! bounded 15m "scripts/arch-check.sh" scripts/arch-check.sh; then
        restore
        fail "scripts/arch-check.sh did not pass; nothing committed; architecture/ restored"
    fi

    # --- 5. commit ------------------------------------------------------------------------------
    since=$(git log -1 --format=%ct -- architecture/export.json) || since=""
    lines=""
    prc=0
    rm -f -- "$RUNTMP/timed-out"
    json=$(rssh curl -s -f --max-time 30 "'$PROPOSALS_URL'") || prc=$?
    if [[ -e $RUNTMP/timed-out ]]; then
        restore
        fail "reading the applied proposals timed out; nothing committed; architecture/ restored"
    elif ((prc == 0)); then
        lines=$(python3 -I -c '
import json, re, sys
from datetime import datetime, timezone
since = float(sys.argv[1] or 0)
rows = json.loads(sys.stdin.read())
if not isinstance(rows, list):
    sys.exit(1)
ID, WORD = re.compile(r"pr_[0-9a-f]{16}"), re.compile(r"[A-Za-z0-9._:@-]{1,64}")
out = []
for r in rows:
    if not isinstance(r, dict):
        continue
    pid, actor, summ, at = r.get("id"), r.get("actor"), r.get("summary"), r.get("decided_at")
    if not (isinstance(pid, str) and ID.fullmatch(pid) and isinstance(at, str)):
        continue
    try:
        t = datetime.fromisoformat(at.replace("Z", "+00:00"))
    except ValueError:
        continue
    if t.tzinfo is None:
        t = t.replace(tzinfo=timezone.utc)
    if t.timestamp() <= since:
        continue
    actor = actor if isinstance(actor, str) and WORD.fullmatch(actor) else "?"
    summ = summ if isinstance(summ, str) else ""
    summ = "".join(ch if ch.isprintable() else " " for ch in summ)[:140].strip()
    out.append((t, f"{pid} {actor} {summ}".rstrip()))
for _, line in sorted(out):
    print(line)
' "$since" <<<"$json") || lines=""
    else
        err "could not read the applied proposals from $HOST; using the fallback subject"
    fi
    msg="$RUNTMP/commit-msg"
    if [[ -n $lines ]]; then
        mapfile -t rows <<<"$lines"
        ids=()
        for r in "${rows[@]}"; do ids+=("${r%% *}"); done
        if ((${#ids[@]} <= 4)); then
            joined=$(printf ', %s' "${ids[@]}")
            subject="architecture: export after ${joined:2}"
        else
            subject="architecture: export after ${ids[0]}, ${ids[1]}, ${ids[2]} and $((${#ids[@]} - 3)) more"
        fi
        { printf '%s\n\nApplied proposals since the last export commit:\n' "$subject"; printf '%s\n' "${rows[@]}"; } >"$msg"
    else
        subject="architecture: export refresh (graph changed)"
        printf '%s\n' "$subject" >"$msg"
    fi
    mapfile -t to_add <<<"$changed"
    git add -- "${to_add[@]}" || { restore; fail "git add failed; architecture/ restored"; }
    if ! bounded 15m "git commit (with its hooks)" git commit -q -F "$msg" -- "${to_add[@]}"; then
        restore
        fail "the commit was refused (hook or git); nothing committed; architecture/ restored"
    fi
    log "committed $(git rev-parse --short HEAD): $subject"
    publish=1
fi

# --- 6. publish -----------------------------------------------------------------------------
if ((publish)); then
    head=$(git rev-parse --short HEAD)
    log "pushing (git push origin main)"
    bounded 2m "git push" git push -q origin main ||
        fail "git push failed; commit $head is in place locally and NOT pushed"
    # deploy-service.sh rsyncs the working tree: ship only exactly what was pushed.
    now=$(git status --porcelain) || now="(git status failed)"
    [[ -z $now ]] ||
        fail "the tree changed after the commit; commit $head is pushed but NOT deployed:"$'\n'"$now"
    [[ $(git rev-parse HEAD) == "$(git rev-parse '@{u}' 2>/dev/null)" ]] ||
        fail "HEAD is not @{u} after the push; commit $head is NOT deployed"
    log "deploying (scripts/deploy-service.sh prod $HOST homelab-arch)"
    bounded 35m "scripts/deploy-service.sh" scripts/deploy-service.sh prod "$HOST" homelab-arch </dev/null ||
        fail "deploy failed; commit $head is in place and pushed, but NOT deployed"
    log "published $head"
fi

# --- 7. freshness ---------------------------------------------------------------------------
rc=0
log "freshness: starting $CHECK_UNIT on $HOST"
start=0
rssh systemctl --user start "$CHECK_UNIT" || start=$?
props=$(rssh systemctl --user show -p LoadState -p Result "$CHECK_UNIT") || props=""
load=$(sed -n 's/^LoadState=//p' <<<"$props" | head -n1)
result=$(sed -n 's/^Result=//p' <<<"$props" | head -n1)
if ((start == 0)) && [[ $load == loaded && $result == success ]]; then
    log "freshness: the graph matches the committed export"
else
    err "FAILED: freshness check: start exit $start, LoadState '${load:-?}', Result '${result:-?}' (journalctl --user -u $CHECK_UNIT on $HOST)"
    rc=1
fi

# --- 8. drift report (never writes) ---------------------------------------------------------
drift=0
src=0
out=$(rssh podman exec "$C" python -m homelab_arch provisioning-sync /infra/architecture/provisioning --check 2>&1) || src=$?
case $src in
0) log "provisioning in sync" ;;
4)
    drift=1
    while IFS= read -r line; do err "DRIFT: $line"; done <<<"$out"
    ;;
*)
    rc=1
    if ((src == 255)); then
        err "FAILED: drift check failed to run: $HOST unreachable over ssh (exit 255)"
    else
        err "FAILED: drift check failed to run (exit $src): container, graph or config problem"
    fi
    while IFS= read -r line; do [[ -n $line ]] && err "  $line"; done <<<"$out"
    ;;
esac

if ((drift && rc == 0)); then
    err "provisioning drift found (report only; nothing was changed)"
    exit 3
fi
exit "$rc"
