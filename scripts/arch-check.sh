#!/usr/bin/env bash
# scripts/arch-check.sh (infra repo): run the homelab-arch architecture checks pinned to the
# commit named in architecture/.checker-ref.
#
# Source of truth: homelab-arch deploy/infra/arch-check.sh. It runs code from a PINNED COMMIT of
# the app inside this repo's tooling, so it:
#   - validates the ref (40 lowercase hex) before using it for anything,
#   - materialises that commit with `git archive` (never executes the live checkout),
#   - builds into <sha>.tmp and renames atomically (a partial build is never used),
#   - installs only with --no-deps --only-binary=:all: from the commit's requirements.lock
#     (--require-hashes when the lock carries hashes), with pip's env/user config ignored. The
#     app itself is NOT pip-installed (that would fetch an unpinned build backend): a .pth file
#     in the venv points at the cached <src>/src instead,
#   - runs every interpreter with -I from `/` so neither cwd nor PYTHONPATH/PYTHONHOME can shadow
#     pinned code.
#
# Environment:
#   HLA_APP_REPO         app repo holding the pinned commit (default $HOME/dev/homelab-arch)
#   XDG_CACHE_HOME       cache root (default $HOME/.cache)
#   HLA_PYTHON           python used to build the venv (default python3; needs >= 3.12)
#   HLA_CHECKER_PYTHON   tests only: skip the venv, run this interpreter with <src>/src on
#                        sys.path. Uses a private temp dir, never the shared cache; warns.
#
# Exit: 0 both checks pass, 1 findings, 2 setup failed or a checker could not run (exit >= 2).
set -euo pipefail
umask 077

die() { printf 'arch-check: %s\n' "$*" >&2; exit 2; }

STAGE=""
cleanup() { if [[ -n $STAGE && -d $STAGE ]]; then rm -rf -- "$STAGE"; fi; return 0; }
trap cleanup EXIT

unset PYTHONHOME PYTHONPATH PYTHONSTARTUP PYTHONUSERBASE PYTHONSAFEPATH PIP_CONFIG_FILE || true

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || die "cannot locate the script"
ROOT=$(dirname -- "$script_dir")
REF_FILE="$ROOT/architecture/.checker-ref"
# Never run Python with the infra working tree as cwd (belt and braces with -I).
cd / || die "cannot cd to /"

[[ -f $REF_FILE && ! -L $REF_FILE ]] || die "$REF_FILE is missing (expected one 40-hex commit)"
REF=$(<"$REF_FILE") || die "cannot read $REF_FILE"
[[ $REF =~ ^[0-9a-f]{40}$ ]] || die "$REF_FILE must hold exactly one full 40-character lowercase hex commit"

APP_REPO=${HLA_APP_REPO:-$HOME/dev/homelab-arch}
[[ -n $APP_REPO && -d $APP_REPO ]] || die "app repo not found: $APP_REPO (set HLA_APP_REPO)"
CACHE_BASE=${XDG_CACHE_HOME:-$HOME/.cache}
[[ $CACHE_BASE == /* ]] || die "XDG_CACHE_HOME must be an absolute path"
CACHE="$CACHE_BASE/homelab-arch-checker"

git_app() { git -C "$APP_REPO" -c core.fsmonitor=false "$@"; }

# The ref must name a commit itself (not a tag, tree or blob that merely peels to one).
resolved=$(git_app rev-parse --verify --quiet "$REF^{commit}" 2>/dev/null) || resolved=""
if [[ $resolved != "$REF" ]]; then
    die "commit $REF is not in $APP_REPO; fetch it with: git -C '$APP_REPO' fetch origin"
fi

OVERRIDE=0
if [[ -n ${HLA_CHECKER_PYTHON:-} ]]; then
    OVERRIDE=1
    [[ -f $HLA_CHECKER_PYTHON && -x $HLA_CHECKER_PYTHON ]] ||
        die "HLA_CHECKER_PYTHON is not an executable file: $HLA_CHECKER_PYTHON"
    printf 'arch-check: WARNING: HLA_CHECKER_PYTHON is set (%s); the venv is skipped and the shared cache is not used. For tests only.\n' \
        "$HLA_CHECKER_PYTHON" >&2
    STAGE=$(mktemp -d "${TMPDIR:-/tmp}/hla-checker.XXXXXX") || die "cannot create a private directory"
    FINAL=$STAGE
else
    FINAL="$CACHE/$REF"
    mkdir -p -- "$CACHE" || die "cannot create $CACHE"
    chmod 700 -- "$CACHE" || die "cannot chmod $CACHE"
    [[ -O $CACHE && ! -L $CACHE ]] || die "$CACHE must be a real directory owned by you"
fi

fill() {
    # $1 = directory to build into; $2 = the path it will finally live at.
    local dir=$1 final=$2
    mkdir -- "$dir/src" || die "cannot create $dir/src"
    git_app archive --format=tar "$REF" | tar -x --no-same-owner --no-same-permissions -C "$dir/src" ||
        die "git archive of $REF failed"
    [[ -f $dir/src/ontology/ontology_v2.yaml ]] || die "commit $REF has no ontology/ontology_v2.yaml"
    if ((OVERRIDE)); then
        return 0
    fi
    local py=${HLA_PYTHON:-python3} lock="$dir/src/requirements.lock" hashes=()
    [[ -f $lock ]] || die "commit $REF has no requirements.lock"
    "$py" -I -c 'import sys; sys.exit(sys.version_info < (3, 12))' 2>/dev/null ||
        die "$py is missing or older than Python 3.12 (set HLA_PYTHON)"
    grep -q -- '--hash=' "$lock" && hashes=(--require-hashes)
    {
        "$py" -I -m venv "$dir/venv" &&
            "$dir/venv/bin/python" -I -m pip install --isolated --disable-pip-version-check -q \
                --no-deps --only-binary=:all: "${hashes[@]}" -r "$lock"
    } >&2 || die "building the checker environment for $REF failed"
    # The app is not pip-installed; the venv sees it through a .pth at its FINAL location.
    local site
    site=$("$dir/venv/bin/python" -I -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])') ||
        die "cannot locate the venv site-packages"
    printf '%s\n' "$final/src/src" >"$site/homelab_arch_pinned.pth" || die "cannot write the .pth file"
    : >"$dir/.complete" || die "cannot write the completion marker"
}

if ((OVERRIDE)); then
    fill "$STAGE" "$STAGE"
else
    if [[ -e $FINAL || -L $FINAL ]]; then
        # Only a completed build is ever renamed to <sha>, so an unmarked one was not made by
        # this script (or was tampered with). Fail closed rather than delete or execute it.
        [[ -d $FINAL && -O $FINAL && ! -L $FINAL && -f $FINAL/.complete ]] ||
            die "$FINAL is incomplete or not yours; remove it (rm -rf '$FINAL') and re-run"
    else
        # A unique stage per run: concurrent runs never touch each other's directories.
        STAGE=$(mktemp -d "$CACHE/$REF.tmp.XXXXXX") || die "cannot create a build directory in $CACHE"
        fill "$STAGE" "$FINAL"
        if mv -T -- "$STAGE" "$FINAL" 2>/dev/null; then
            STAGE=""
        else
            # Lost a race to a concurrent build of the same commit: use theirs if it is complete.
            [[ -d $FINAL && -O $FINAL && ! -L $FINAL && -f $FINAL/.complete ]] ||
                die "cannot publish the checker cache $FINAL"
        fi
    fi
fi
SRC="$FINAL/src"

run_check() {
    if ((OVERRIDE)); then
        "$HLA_CHECKER_PYTHON" -I -c '
import runpy, sys
src, mod = sys.argv[1], sys.argv[2]
sys.path.insert(0, src)
sys.argv = [mod] + sys.argv[3:]
runpy.run_module(mod, run_name="__main__", alter_sys=True)
' "$SRC/src" "$@"
    else
        "$FINAL/venv/bin/python" -I -m "$@"
    fi
}

worst=0
record() { # exit code -> 0 ok, 1 findings, 2 could not run (including 127 and signals)
    local c=$1
    ((c > 2)) && c=2
    ((c > worst)) && worst=$c
    return 0
}
rc=0
run_check homelab_arch.checks --provisioning "$ROOT/architecture/provisioning" \
    --ontology "$SRC/ontology/ontology_v2.yaml" || rc=$?
record "$rc"
rc=0
run_check homelab_arch.checks.alignment "$ROOT" \
    --ontology "$SRC/ontology/ontology_v2.yaml" || rc=$?
record "$rc"
exit "$worst"
