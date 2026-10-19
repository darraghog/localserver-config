# homelab-arch export sync on beeblebox

The daily publish of approved graph changes runs **on beeblebox** as the user unit
`localserver-homelab-arch-export-sync` (09:00), like the backup and the weekly export check. It
needs no ssh. A failure leaves the unit failed, `scripts/emit-unit-metrics.sh` reports it, and the
`SystemdUserUnitFailed` alert posts to Slack #myagentchannel after 5 minutes, with no new alerting
secret.

Source of truth for the script and units: homelab-arch `deploy/infra/` (patch series 0006). The
lifecycle it implements: `~/dev/homelab-arch/docs/change-playbook.md` section 3 step 5.

## How it is laid out

| Tree | What | Who writes it |
|---|---|---|
| `~/localserver-config` (deploy tree) | rsync `--delete` mirror of the workstation (no `.git`); the container bind-mounts its `architecture/` at `/infra/architecture`; the script and units run from here | the owner's deploys; the job writes **only** the four export files into `architecture/` |
| `~/localserver-config-sync` (clone) | dedicated git clone, only this job touches it | the job: pull, export, check, commit, push |
| `~/dev/homelab-arch` | app checkout holding the commit pinned in `architecture/.checker-ref`, for `scripts/arch-check.sh` | the owner (fetch when re-pinning) |

The job never works in the deploy tree: a deploy overwrites it, it has no `.git`, and a `git pull`
there would be undone by the next rsync.

## One-time setup

Do the steps in this order. `scripts/sudo/bootstrap-host.sh` enables every `localserver-*.timer`
it finds, so run it (or the manual install in step 6) only after steps 1 to 5.

Run steps 1 to 5 on beeblebox as the service user.

1. **Python 3.12 or newer** for the pinned checker's venv: `python3 --version`. If it is older,
   install `python3.12` and `python3.12-venv`, and uncomment `Environment=HLA_PYTHON=...` in the
   unit. The first run builds the checker's venv from PyPI (hash-pinned) and caches it under
   `~/.cache/homelab-arch-checker`, so beeblebox needs outbound HTTPS and that first run is slower.
2. **App checkout** with the pinned commit:
   `git clone https://github.com/darraghog/homelab-arch.git ~/dev/homelab-arch`, then
   `git -C ~/dev/homelab-arch cat-file -t "$(cat ~/localserver-config/architecture/.checker-ref)"`
   must print `commit`. Whenever `.checker-ref` is re-pinned (playbook section 2 step 5), also run
   `git -C ~/dev/homelab-arch fetch` on beeblebox, or the job's checker step fails.
3. **Dedicated clone, with the hook wired:**
   ```
   git clone https://github.com/darraghog/localserver-config.git ~/localserver-config-sync
   git -C ~/localserver-config-sync config core.hooksPath .githooks
   ```
   The job refuses to run unless `core.hooksPath` is `.githooks`: that is what makes "never
   `--no-verify`" true.
4. **Git write credential** (the one new secret on the server). Create a GitHub **fine-grained
   personal access token** limited to the single repository `darraghog/localserver-config`, with
   *Contents: Read and write* and nothing else, and an expiry (calendar it). Store it for that
   clone only, typing it yourself at a silent prompt (never paste it into an agent session or
   onto a command line):
   ```
   git -C ~/localserver-config-sync config credential.helper \
     'store --file ~/.config/arch-sync/git-credentials'
   install -d -m 700 ~/.config/arch-sync
   read -rsp 'GitHub fine-grained PAT: ' PAT; echo
   printf 'protocol=https\nhost=github.com\nusername=darraghog\npassword=%s\n\n' "$PAT" \
     | git -C ~/localserver-config-sync credential approve
   unset PAT
   chmod 600 ~/.config/arch-sync/git-credentials
   ```
   Check: `git -C ~/localserver-config-sync pull --ff-only` succeeds. The file is not backed up
   (regenerate the token if the host is rebuilt). When the token expires the job fails at
   `git pull` with "the git credential on this host expired?" and the alert fires.
5. **Dry look** (changes nothing): `git -C ~/localserver-config-sync status` is clean on `main`,
   and `podman exec homelab-arch_app_1 true` works.
6. **Ship the code and install the units.** On the workstation (patches 08 and 09 are already
   applied, since you are reading this file): push, and deploy (for example
   `./scripts/deploy-service.sh prod beeblebox homelab-arch`), so the new script and units reach
   `~/localserver-config`. Then on beeblebox either run
   `scripts/sudo/bootstrap-host.sh` or install just these two units:
   ```
   cd ~/localserver-config
   for u in localserver-homelab-arch-export-sync.service localserver-homelab-arch-export-sync.timer; do
     sed -e "s|__REPO_ROOT__|$HOME/localserver-config|g" -e "s|__HOME__|$HOME|g" \
       "systemd/user/$u" > "$HOME/.config/systemd/user/$u"
   done
   systemctl --user daemon-reload
   ```
   Do **not** `enable` the timer yet.
7. **First run by hand**, watching it:
   `systemctl --user start localserver-homelab-arch-export-sync.service` and
   `journalctl --user -u localserver-homelab-arch-export-sync -f`. Expected, if proposals were
   approved since the last export commit: pull, export, check, an `architecture: export after
   pr_...` commit, push, `installed architecture/...`, `published`, freshness ok, then either
   `provisioning in sync` or DRIFT lines (exit 3, which is the drift alarm in the playbook, not a
   setup error). Then confirm `export_status` (MCP) is `fresh`.
8. **Prove the alert path** end to end, harmlessly:
   `systemd-run --user --unit=localserver-alert-test /bin/false`. Within about 6 minutes
   `SystemdUserUnitFailed` for `localserver-alert-test.service` must reach #myagentchannel. Then
   `systemctl --user reset-failed localserver-alert-test.service`.
9. **Enable:** `systemctl --user enable --now localserver-homelab-arch-export-sync.timer`.
10. **Retire the workstation timer** (your machine, outside this repo): on the laptop,
    `systemctl --user disable --now localserver-homelab-arch-export-sync.timer`, and remove its
    two unit files from `~/.config/systemd/user`. Leaving it enabled would run a second publisher
    that fails on the Tailscale SSH check every day.

## Day to day

- The server now adds `architecture: export after ...` commits to `origin/main`. On the
  workstation, `git pull --rebase` before committing, pushing or deploying. A deploy rsyncs the
  workstation's `architecture/` over the server's: an older copy there makes the export look stale
  until the next 09:00 run heals it (the job re-installs the committed export every run).
- A change in progress alerts. Between deploying a provisioning change and committing the YAML and
  `architecture/` together (playbook section 4, steps 2 to 5), the 09:00 run exports the new graph,
  the checker compares it with the still-committed YAML and fails, and the unit alerts (exit 1).
  That is expected: finish the commit, or accept the alert until you do.
- Run it early: `systemctl --user start localserver-homelab-arch-export-sync.service` on beeblebox.
- Exit codes: 0 done, 1 a step failed, 2 refused (clone missing, not on main, hooks not wired,
  tree dirty, unpushed commits), 3 provisioning drift found. All non-zero exits alert.
- If the clone is dirty or ahead (exit 2), it was touched by hand: look with
  `git -C ~/localserver-config-sync status` and clean it; the job never fixes that itself.

## Security trade-off

The server now holds a credential that can push to `main` of the infra repo, which the owner later
deploys everywhere. The token is limited to that one repository and the job's commits are
restricted to four generated files by the script and the pre-commit gate, but a compromised
server could push anything the token allows. If that is not acceptable, skip steps 4 and 9 and
let the existing weekly `localserver-homelab-arch-export-check` alert on a stale export, then
publish by hand from the workstation (`scripts/arch-export.sh`, review, commit, deploy).

## Rollback

`systemctl --user disable --now localserver-homelab-arch-export-sync.timer` on beeblebox, then
re-enable the workstation timer. Nothing else depends on the server job.
