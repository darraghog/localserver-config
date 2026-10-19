#!/usr/bin/env bash
# scripts/arch-sync-export.sh (infra repo): the daily publish of approved graph changes, run ON
# THE SERVER (beeblebox) from localserver-homelab-arch-export-sync.service (daily 09:00, via its
# timer). Nothing here uses ssh: the container, the export-check unit and the deployed tree are
# all on this host, so a failure is a failed user unit and the existing SystemdUserUnitFailed
# alert (emit-unit-metrics.sh -> Alertmanager -> Slack) reports it.
#
# Source of truth: homelab-arch deploy/infra/arch-sync-export.sh.
#
# Two trees, kept apart on purpose:
#   DEPLOY  the tree this script runs from (~/localserver-config on the server). It is an rsync
#           --delete mirror of the owner's workstation (no .git), the container bind-mounts its
#           architecture/ at /infra/architecture, and the owner's deploys overwrite it. This
#           script only ever writes the four export files into it, never anything else.
#   CLONE   a dedicated git clone (HLA_SYNC_CLONE) that only this job touches: pull, export,
#           check, commit, push all happen there. Running from DEPLOY (not CLONE) also means a
#           `git pull` never rewrites the script while bash is still reading it.
#
# Direction: graph -> git is PUBLISHED (approved proposals already changed the graph; this
# commits the re-export and installs it). git -> graph drift (committed provisioning YAML vs the
# graph) is only REPORTED: provisioning-sync is only ever run with --check.
#
# Steps:
#   1. flock ${XDG_RUNTIME_DIR:-/tmp}/arch-sync-export.lock; held by another run -> exit 0.
#   2. Refuse (exit 2) unless CLONE is a git clone other than DEPLOY, on main, with
#      core.hooksPath=.githooks (so the pre-commit gate really runs), a clean
#      `git status --porcelain` and no local commit ahead of @{u} (unpushed commits are never
#      published by this script: their net diff could hide an intermediate commit, and they
#      never went through arch-check here); then `git pull --ff-only`.
#   3. scripts/arch-export.sh with HLA_EXPORT_LOCAL=1 (podman exec on this host). No change ->
#      "export unchanged", go to 6.
#   4. Only architecture/{export.json,model.yaml,metamodel.yaml,overview.html} may change, and
#      scripts/arch-check.sh must pass; otherwise architecture/ is restored and the run fails.
#   5. Commit those files (never --no-verify): "architecture: export after <ids>", the body
#      listing `id actor summary` of each applied proposal decided after the last commit that
#      touched architecture/export.json; "architecture: export refresh (graph changed)" when the
#      proposals cannot be read or none qualify. A refusing hook restores the files. Then
#      git push origin main.
#   6. Install: only if the tree is still clean and HEAD equals @{u}, copy the four export files
#      from CLONE into DEPLOY/architecture (atomic rename, only when they differ). This runs on
#      every run, so a copy that failed yesterday is retried today. No restart is needed: the
#      container reads the directory live. A failure keeps the commit and says whether it was
#      pushed.
#   7. Freshness: start localserver-homelab-arch-export-check.service (a oneshot start blocks, so
#      its exit status counts) and require LoadState=loaded and Result=success. A failure is
#      exit 1, but step 8 still runs.
#   8. Drift report: provisioning-sync /infra/architecture/provisioning --check in the container.
#      Drift is exit 3; a check that cannot run (podman, container, config) is exit 1, and so is
#      a check that refuses the files (provisioning-sync exit 1: findings or a blocked removal).
#      Exit 3 is deliberately a FAILED unit: drift should alert, not wait to be noticed.
#
# Environment:
#   HLA_SYNC_CLONE the dedicated clone (default $HOME/localserver-config-sync); absolute, and not
#                  the tree this script runs from
#   HLA_CONTAINER  app container (default homelab-arch_app_1); must match ^[A-Za-z0-9._-]+$, not
#                  start with -
#   HLA_APP_REPO, HLA_PYTHON  read by scripts/arch-check.sh (the app checkout holding the pinned
#                  commit, and the python >= 3.12 used for its venv)
# Every external command runs under `timeout` (podman exec 2m, git pull/push 2m, curl 2m,
# systemctl 2m, arch-export 15m, arch-check 15m, git commit with its hook 15m); a timeout is exit
# 1 with a TIMED OUT message, said only when `timeout` itself fired (a command's own 124/137 is
# not one). git push/pull use HTTPS with GIT_TERMINAL_PROMPT=0, so missing or expired credentials
# fail the run instead of waiting for a prompt.
#
# Exit codes:
#   0  done, or nothing to do (including: another run holds the lock)
#   1  a step failed (pull, export, path/check refusal, commit hook, push, install, freshness,
#      a drift check that could not run, any timeout)
#   2  refused: clone missing, not on main, not clean, hooks not wired, local commits not pushed,
#      or a bad env word
#   3  everything else succeeded but provisioning drift was found (the DRIFT lines say what)
set -euo pipefail
umask 022

log() { printf '[arch-sync] %s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"; }
err() { log "$@" >&2; }
refuse() { err "REFUSED: $*"; exit 2; }
fail() { err "FAILED: $*"; exit 1; }

export GIT_TERMINAL_PROMPT=0
export HLA_EXPORT_LOCAL=1

C=${HLA_CONTAINER-homelab-arch_app_1}
re='^[A-Za-z0-9._-]+$'
[[ $C =~ $re && $C != -* ]] || refuse "HLA_CONTAINER must match ^[A-Za-z0-9._-]+\$ and not start with '-'"
export HLA_CONTAINER=$C
CLONE=${HLA_SYNC_CLONE-${HOME:-}/localserver-config-sync}
[[ $CLONE == /* ]] || refuse "HLA_SYNC_CLONE must be an absolute path (got '$CLONE')"

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
# podman exec in the app container; the command line is fixed apart from the arguments.
pexec() { bounded 2m "podman exec" podman exec "$C" "$@"; }

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
DEPLOY=$(dirname -- "$script_dir")
CLONE=$(cd -- "$CLONE" 2>/dev/null && pwd -P) || refuse "HLA_SYNC_CLONE is not a directory: $CLONE"
[[ -e $CLONE/.git ]] || refuse "$CLONE is not a git clone (no .git)"
[[ $CLONE != "$DEPLOY" ]] ||
    refuse "HLA_SYNC_CLONE is the tree this script runs from ($DEPLOY): that tree is overwritten by the owner's deploys and has no .git; use a dedicated clone"
cd -- "$CLONE" || fail "cannot cd to $CLONE"

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
hooks=$(git config --get core.hooksPath) || hooks=""
[[ $hooks == .githooks ]] ||
    refuse "core.hooksPath is '${hooks:-unset}' in $CLONE, not .githooks, so the pre-commit gate would not run (git -C $CLONE config core.hooksPath .githooks)"
dirty=$(git status --porcelain) || fail "git status failed"
[[ -z $dirty ]] || refuse "the checkout is not clean (git status --porcelain):"$'\n'"$dirty"
ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null) || refuse "main has no upstream (@{u}) to compare with"
((ahead == 0)) || refuse "local main has unpushed commits; push or reset them first ($ahead ahead of @{u})"
log "pulling (git pull --ff-only)"
bounded 2m "git pull" git pull -q --ff-only || fail "git pull --ff-only failed (network, or the git credential on this host expired?)"

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
        fail "scripts/arch-check.sh did not pass; nothing committed; architecture/ restored (a missing pinned commit means HLA_APP_REPO on this host needs a git fetch)"
    fi

    # --- 5. commit ------------------------------------------------------------------------------
    since=$(git log -1 --format=%ct -- architecture/export.json) || since=""
    lines=""
    prc=0
    rm -f -- "$RUNTMP/timed-out"
    json=$(bounded 2m "reading the applied proposals" curl -s -f --max-time 30 "$PROPOSALS_URL") || prc=$?
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
        err "could not read the applied proposals; using the fallback subject"
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

# --- 5b. push -------------------------------------------------------------------------------
if ((publish)); then
    head=$(git rev-parse --short HEAD)
    log "pushing (git push origin main)"
    bounded 2m "git push" git push -q origin main ||
        fail "git push failed; commit $head is in place locally and NOT pushed"
fi

# --- 6. install the committed export into the deployed tree ----------------------------------
# Install only exactly what is pushed: the tree must be clean and HEAD must be @{u}.
head=$(git rev-parse --short HEAD)
now=$(git status --porcelain) || now="(git status failed)"
[[ -z $now ]] ||
    fail "the tree changed after the commit; $head is not installed into $DEPLOY:"$'\n'"$now"
[[ $(git rev-parse HEAD) == "$(git rev-parse '@{u}' 2>/dev/null)" ]] ||
    fail "HEAD is not @{u}; $head is NOT installed into $DEPLOY"

# Copy one export file into DEPLOY/architecture when it differs: temp file in the same directory,
# then rename, so the container never reads a half-written file.
install_one() {
    local f=$1 src="$CLONE/$1" dst="$DEPLOY/$1" tmpf
    [[ -f $src && ! -L $src ]] || { err "$src is not a regular file"; return 1; }
    [[ ! -L $dst ]] || { err "$dst is a symlink; refusing to write through it"; return 1; }
    if [[ -f $dst ]] && cmp -s -- "$src" "$dst"; then return 0; fi
    tmpf=$(mktemp "$dst.XXXXXX") || return 1
    if cat -- "$src" >"$tmpf" && chmod 644 -- "$tmpf" && mv -f -- "$tmpf" "$dst"; then
        log "installed $f into $DEPLOY"
        return 0
    fi
    rm -f -- "$tmpf"
    return 1
}
[[ -d $DEPLOY/architecture && ! -L $DEPLOY/architecture ]] ||
    fail "$DEPLOY/architecture is not a directory; $head is NOT installed"
for f in "${FILES[@]}"; do
    install_one "$f" || fail "could not install $f into $DEPLOY; commit $head is in the clone (pushed if it was new) but NOT installed here"
done
if ((publish)); then log "published $head"; fi

# --- 7. freshness ---------------------------------------------------------------------------
rc=0
log "freshness: starting $CHECK_UNIT"
start=0
bounded 2m "starting $CHECK_UNIT" systemctl --user start "$CHECK_UNIT" || start=$?
props=$(bounded 2m "reading $CHECK_UNIT state" systemctl --user show -p LoadState -p Result "$CHECK_UNIT") || props=""
load=$(sed -n 's/^LoadState=//p' <<<"$props" | head -n1)
result=$(sed -n 's/^Result=//p' <<<"$props" | head -n1)
if ((start == 0)) && [[ $load == loaded && $result == success ]]; then
    log "freshness: the graph matches the committed export"
else
    err "FAILED: freshness check: start exit $start, LoadState '${load:-?}', Result '${result:-?}' (journalctl --user -u $CHECK_UNIT)"
    rc=1
fi

# --- 8. drift report (never writes) ---------------------------------------------------------
drift=0
src=0
out=$(pexec python -m homelab_arch provisioning-sync /infra/architecture/provisioning --check 2>&1) || src=$?
case $src in
0) log "provisioning in sync" ;;
4)
    drift=1
    while IFS= read -r line; do err "DRIFT: $line"; done <<<"$out"
    ;;
1)
    rc=1
    err "FAILED: provisioning-sync --check refused the provisioning files (exit 1): input findings or a blocked removal, not drift; nothing was written"
    err "  fix it per ~/dev/homelab-arch/docs/change-playbook.md section 5 (a blocked removal needs its graph-owned edges removed by proposal first)"
    while IFS= read -r line; do [[ -n $line ]] && err "  $line"; done <<<"$out"
    ;;
*)
    rc=1
    if ((src == 125 || src == 126 || src == 127)); then
        err "FAILED: drift check failed to run: podman could not run it (exit $src): is $C running?"
    else
        err "FAILED: drift check failed to run (exit $src): container, graph or config problem"
    fi
    while IFS= read -r line; do [[ -n $line ]] && err "  $line"; done <<<"$out"
    ;;
esac

if ((drift && rc == 0)); then
    err "provisioning drift found (report only; nothing was changed)"
    err "provisioning drift: follow ~/dev/homelab-arch/docs/change-playbook.md section 4, or docs/ADD-SERVICE.md section 10 steps 2-3 (deploy, then scripts/provisioning-sync.sh)"
    exit 3
fi
exit "$rc"
