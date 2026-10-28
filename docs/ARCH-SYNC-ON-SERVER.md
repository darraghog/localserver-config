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
| `~/localserver-config` (deploy tree) | git clone of `origin`, fast-forwarded by deployd's `sync-infra` (the gate needs it clean and equal to `origin/main`); the container bind-mounts its `architecture/` at `/infra/architecture`; the script and units run from here | `deployctl request sync-infra` only; the job never writes into it (see the note below) |
| `~/localserver-config-sync` (clone) | dedicated git clone, only this job touches it | the job: pull, export, check, commit, push |
| `~/dev/homelab-arch` | app checkout holding the commit pinned in `architecture/.checker-ref`, for `scripts/arch-check.sh` | the owner (fetch when re-pinning) |

The job does its git work (pull, export, check, commit, push) only in the dedicated clone, never in
the deploy tree: running from the deploy tree means a `git pull` cannot rewrite the script while
bash is reading it, and only `sync-infra` moves that tree.

Note: when the deploy tree is a git clone (it has `.git`), step 6 of the script does not copy the
export files into it: copies would be tracked modifications and the infra gate would report
`dirty`. The export commit reaches `architecture/` there through an approved `sync-infra`. Step 7
(freshness) compares the four files in the clone with the deploy tree: if any differ it logs
`freshness: skipped, N export file(s) ... await sync-infra` and does not fail, because the check
compares the live graph with the deploy tree's `architecture/` and could only fail until the sync.
Without `.git` (an older layout) step 6 still copies them, as before.

## One-time setup

Do the steps in this order. `scripts/sudo/bootstrap-host.sh` enables every `localserver-*.timer`
it finds, so run it (or the manual install in step 6) only after steps 1 to 5.

Run steps 1 to 5 on beeblebox as the service user.

1. **Python 3.12 or newer** for the pinned checker's venv: `python3 --version` (3.14.4 worked on
   beeblebox). If it is older,
   install `python3.12` and `python3.12-venv`, and uncomment `Environment=HLA_PYTHON=...` in the
   unit. The first run builds the checker's venv from PyPI (hash-pinned) and caches it under
   `~/.cache/homelab-arch-checker`, so beeblebox needs outbound HTTPS and that first run is slower.
2. **App checkout** with the pinned commit. `homelab-arch` is a **private** repo, so give beeblebox
   a read-only **deploy key** first (no expiry, one repo, no new token):
   ```
   install -d -m 700 ~/.ssh
   ssh-keygen -t ed25519 -N '' -f ~/.ssh/homelab-arch-deploy -C beeblebox-homelab-arch
   cat ~/.ssh/homelab-arch-deploy.pub
   ```
   Add that public line in GitHub under the `homelab-arch` repo, Settings, Deploy keys, with
   *Allow write access* unticked. Then clone, and save the key in the clone so later fetches work:
   ```
   ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
   GIT_SSH_COMMAND='ssh -i ~/.ssh/homelab-arch-deploy -o IdentitiesOnly=yes' \
     git clone git@github.com:darraghog/homelab-arch.git ~/dev/homelab-arch
   git -C ~/dev/homelab-arch config core.sshCommand \
     'ssh -i ~/.ssh/homelab-arch-deploy -o IdentitiesOnly=yes'
   ```
   (`ssh-keyscan` trusts GitHub's key on first use; compare `ssh-keygen -lf ~/.ssh/known_hosts` with
   GitHub's published fingerprints if you want to verify it.) Then
   `git -C ~/dev/homelab-arch cat-file -t "$(cat ~/localserver-config/architecture/.checker-ref)"`
   must print `commit`. Whenever `.checker-ref` is re-pinned (playbook section 2 step 5), also run
   `git -C ~/dev/homelab-arch fetch` on beeblebox, or the job's checker step fails.
3. **Dedicated clone, with the hook wired** (this repo is public, so the clone needs no credential;
   only the push in step 4 does):
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
   Check: `git -C ~/localserver-config-sync pull --ff-only` succeeds, and so does
   `git -C ~/localserver-config-sync push --dry-run origin main` (the repo is public, so only the
   push proves the token works). The file is not backed up
   (regenerate the token if the host is rebuilt; the deploy key in `~/.ssh` is not backed up either). When the token expires the job fails at
   `git pull` with "the git credential on this host expired?" and the alert fires.
5. **Dry look** (changes nothing): `git -C ~/localserver-config-sync status` is clean on `main`,
   and `podman exec homelab-arch_app_1 true` works.
6. **Ship the code and install the units.** On the workstation (patches 08 and 09 are already
   applied, since you are reading this file): push, then
   `deployctl request sync-infra` (the owner approves it), so the new script and units reach
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
   pr_...` commit, push, `not writing into it` (or `installed architecture/...` on an older
   layout without `.git`), `published`, freshness skipped (or ok), then either
   `provisioning in sync` or DRIFT lines (exit 3, which is the drift alarm in the playbook, not a
   setup error). Then confirm `export_status` (MCP) is `fresh`. A run with nothing new logs `export unchanged` and
   skips the commit, push and install steps, so the first run after a real approved change is the
   first full test of those. Ignore the line "Review: git diff architecture/ then commit yourself.
   Nothing was committed.": it comes from `arch-export.sh` and does not apply to this job.
8. **Prove the alert path** end to end, harmlessly:
   `systemd-run --user --unit=localserver-alert-test /bin/false`. Within about 6 minutes
   `SystemdUserUnitFailed` for `localserver-alert-test.service` must reach #myagentchannel. Then
   `systemctl --user reset-failed localserver-alert-test.service`.
9. **Enable:** `systemctl --user enable --now localserver-homelab-arch-export-sync.timer`.
10. **Retire the workstation timer** (your machine, outside this repo): on the laptop,
    `systemctl --user disable --now localserver-homelab-arch-export-sync.timer`, and remove its
    two unit files from `~/.config/systemd/user` (check the path first, and leave the
    `localserver-homelab-arch-export-check` units alone). Leaving it enabled would run a second publisher
    that fails on the Tailscale SSH check every day.

## Day to day

- The server now adds `architecture: export after ...` commits to `origin/main`. On the
  workstation, `git pull --rebase` before committing, pushing or deploying. Prod is deployed by
  deployd, not by rsync: push, then `deployctl request sync-infra` brings the server's clone to that
  commit. `deploy-to-server.sh` and `deploy-service.sh` refuse `prod`.
- After an approved graph change, the 09:00 run pushes the export commit but does not touch the
  server's `architecture/`. The live model view in the homelab-arch container updates only after
  `sync-infra`: `deployctl request infra-diff` (state `behind`, only `architecture/` changed, no
  stacks affected), then `deployctl request sync-infra ref=<origin sha>`, which the owner approves.
  Until then the freshness step is logged as skipped, `infra-diff` stays `behind` (never `dirty`),
  and the weekly `localserver-homelab-arch-export-check` fails; that failure is the reminder.
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
