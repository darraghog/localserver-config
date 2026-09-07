# Agent guidance layer: CLAUDE.md, an add-service skill, and a model↔filesystem gate

*Design, 2026-09-07. Status: approved, pending implementation plan.*

## Problem

An agent working in this repo has no in-repo guidance. `.claude/` holds only
`settings.json` and ignored worktrees. Everything an agent needs to know lives in three
places it will not read unprompted:

- `docs/ADD-SERVICE.md` — an eleven-step checklist for publishing a service.
- `docs/NETWORK-CONFIG.md` — 32KB of host-networking constraints.
- The maintainer's per-user Claude memory — which does not travel with the repo.

The memory index is the evidence that this costs something. Every entry in it is a
correction of an agent that got the estate wrong: a healthy service reported as broken, n8n
moved off `:443` and breaking claude.ai's connector, everything defaulted to tailnet-only,
litellm path-mounted when it cannot be, per-service detail written into platform docs.

Two further gaps compound it:

- **Conventions are unwritten.** Commit voice, shell idiom, docs placement and the
  `HOST_INTERNAL_IP` rule are consistent in the tree but stated nowhere, so each agent
  re-infers them.
- **The enforced registry is not fully enforced.** `scripts/arch-validate.py` checks that
  `architecture/model.yaml` is internally consistent. It never reads the filesystem. A stack
  can exist on disk and be entirely absent from the model, and both the pre-commit hook and
  `require_conformant_model()` will pass it.

## Scope

This pass delivers three artefacts. The remaining four skills identified in review
(`deploy-and-verify`, `stack-health`, `update-image`, `network-troubleshooting`) are
deliberately deferred until the shape of the first one has been used against a real task.

1. `CLAUDE.md` at the repo root — always-on conventions.
2. `.claude/skills/add-service/SKILL.md` — a triggered procedure.
3. A filesystem cross-check in `scripts/arch-validate.py`, plus the metamodel change it
   needs.

### Out of scope, and why

- **Migrating the maintainer's memory entries into the repo.** They are architectural
  decision records. A decision-record process — likely spanning projects, not specific to
  this repo — is a separate decision to be made later. Where a specific estate exception
  matters, the guidance cites the existing `docs/NETWORK-CONFIG.md` section rather than
  restating the fact.
- **A Caddy-port ↔ `ApplicationService` cross-check.** Investigated and rejected; see
  "Rejected: port-level service checking" below.
- **Rewriting `docs/ADD-SERVICE.md`.** It stays canonical and unmodified.

## Artefact 1 — `CLAUDE.md`

Repo root. Always-on conventions only: no estate facts, no per-service detail, nothing that
belongs in `model.yaml`.

### Contents

**Orientation.** Three lines: `scripts/` is no-sudo, `scripts/sudo/` is privileged,
`compose/<name>/` is one stack each, `architecture/model.yaml` is the enforced registry.

**Hard rules.** Stated as prohibitions, because each has a known failure behind it:

| Rule | Failure it prevents |
|---|---|
| Publish as `"${HOST_INTERNAL_IP:?…}:port:port"`, never a literal address | The value is per-host — `127.0.0.1` on prod, `10.255.255.254` on WSL. A literal works on one and silently fails on the other. |
| No bind mount for stack state under `compose/<name>/` — use a named volume | `deploy-service.sh` rsyncs with `--delete` and wipes it on every deploy. |
| Container→container goes to `host.containers.internal:<port>` over plain HTTP, never through Caddy | The `:844x` sites serve a private CA whose SANs do not cover container-visible names. |
| Services are never described in `README.md` or `NETWORK-CONFIG.md` | Services are data in `model.yaml`; per-app notes belong in `compose/<name>/README.md`. |

**Commit voice.** Imperative, sentence case, stating intent rather than mechanism. No
`feat:`/`fix:` prefixes. Two examples drawn from the log: "Let WordPress take its site URL
from the environment", "Fail the deploy when WordPress has no credentials".

**Shell idiom.** `#!/usr/bin/env bash` (uniform across all 23 scripts).
`REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` (uniform across all 16 that
need it). Errors to stderr, carrying the next step rather than only the failure. Comments
explain why, not what — `scripts/lib/stack-helpers.sh` is the reference.

One point must be stated honestly rather than as a uniform rule: error handling is mixed in
the tree, `set -e` in eighteen scripts and `set -euo pipefail` in eleven. `CLAUDE.md`
prescribes `set -euo pipefail` for new scripts and records that the older form is
pre-existing, not wrong.

**Environments.** Two: `local` and `prod`. `envs/dev.env` is aspirational and no dev
environment exists. A prod deploy rsyncs the *working tree*, so uncommitted edits ship —
commit before deploying.

## Artefact 2 — `.claude/skills/add-service/SKILL.md`

An orchestrator, not a second copy of the checklist. `docs/ADD-SERVICE.md` remains canonical;
the skill sequences the work, names the decision at each step, states the trap an agent falls
into, and links to the doc section for detail. Target length is roughly ninety lines.

Duplicating the doc was considered and rejected: it would put ~300 lines under two paths that
drift on the next change.

### Steps

Each carries *what to do*, *the trap*, and *where the detail is*.

1. **Decide the exposure tier before anything else.** Public Funnel on `:443`, the `:8090`
   tailnet path router, or a dedicated tailnet port. This is a risk decision, not a default.
   → `NETWORK-CONFIG.md#tailnet-path-routing`, which already documents why n8n is
   root-mounted on `:443` and why litellm needs its own port.
2. **Scaffold** — `./scripts/add-service.sh <name> --port <p> --image <img>`.
3. **`compose.yaml`** — three traps: `${HOST_INTERNAL_IP:?…}` publishing, a named volume
   rather than a bind, and a healthcheck (every existing stack has one).
4. **`build.sh`** — every stack has one, including image-only stacks.
5. **`stack-order`** — the new name goes before `tls-proxy`.
6. **Caddyfile site block** — and the inode trap: the Caddyfile is bind-mounted as a single
   file, so after an rsync a `caddy reload` re-reads the *previous* config and reports
   success. `start-stack.sh` force-recreates `tls-proxy` for this reason.
7. **`.env.example`** and the `envs/*.env` files.
8. **`tests/check-ports.sh`** — hand-maintained parallel arrays; easy to miss.
9. **`architecture/model.yaml`** — an `ac-<id>` carrying `stack: compose/<name>`, plus an
   `as-<id>` with exactly one `exposed_via`. Flagged as the most-skipped step. After this
   design lands it is also the one the validator catches.
10. **Deploy and verify.**

### Triggering

The frontmatter description must fire on the phrasings actually used: adding a service or
stack, exposing something, putting something behind Caddy, running a new container.

## Artefact 3 — filesystem cross-check in `arch-validate.py`

### What investigation changed

Two assumptions from the review did not survive contact with the model, and the design
reflects the corrections.

**Entity ids are not derivable from directory names.** `claude-mock-test` is `ac-claudemock`,
`tic-tac-toe` is `ac-tictactoe`, `hello-world` is `ac-helloworld` — but `weather-mcp` is
`ac-weather-mcp`. A name-based join would produce false failures on three of eight stacks.
The reliable key is the `stack:` attribute, which every `ApplicationComponent` already
carries in the form `compose/<name>`.

**Rejected: port-level service checking.** `ApplicationService` endpoints are deliberately
aggregate — `as-lan-consoles` is `https://beeblebox:8443-8449, :9443`; `as-demos-private` is
`:8090/{tictactoe,helloworld}`. Twelve Caddy site ports map to ten services, intentionally.
Enforcing one service per port would require restructuring the model into something less
readable in order to satisfy a checker. That half of the idea is dropped.

### Rules

- **`[every-stack-is-modelled]`** — every `compose/*/` directory is named by the `stack:`
  attribute of some entity. Catches a service added to disk but never modelled. The check
  collects `stack:` from entities of *any* type rather than only `ApplicationComponent`;
  that is what lets `ts-caddy` claim `compose/tls-proxy` without a special case, and it
  keeps the rule working if a future stack is modelled at another layer.
- **`[no-phantom-stacks]`** — every `stack:` value beginning `compose/` names a directory
  that exists. Catches removals and renames. Non-path values are ignored, so
  `ac-cockpit`'s `stack: (host package, not containerised)` passes correctly.

Both are errors, not warnings: they run through the existing `err()` path, so the pre-commit
hook and `require_conformant_model()` pick them up with no change to either. The hook's
existing trigger already covers the new rules — it fires on staged paths matching
`architecture/`, `compose/` or `scripts/arch-validate.py`, and adding a stack stages
`compose/`.

### Metamodel change

`compose/tls-proxy` has no `ApplicationComponent` — Caddy is modelled as `ts-caddy`, a
`TechnologyService`, whose schema declares only `product`. `[every-stack-is-modelled]` would
therefore fail on it.

The chosen fix is to add an optional `stack:` attribute to `TechnologyService` in
`architecture/metamodel.yaml` and set `stack: compose/tls-proxy` on `ts-caddy`. The rule then
stays uniform across every stack, and the fact that Caddy ships from that directory becomes
data in the model rather than an assumption.

The alternative — a `PLATFORM_STACKS = {"tls-proxy"}` exemption hardcoded in the validator —
was rejected. It would put a statement about the estate in Python rather than in the model,
against the repo's stated principle that such facts are recorded as data so the prose need
not narrate them.

### Current drift

None, once `ts-caddy` gains its `stack:` attribute. The other seven directories all resolve
to an `ApplicationComponent`, and no `ac-` names a directory that does not exist. The
cross-check passes on the tree as it stands, so it can be added without a preparatory
cleanup.

## Testing

- `python3 scripts/arch-validate.py` exits 0 on the current tree after the `ts-caddy` change.
- Temporarily create an empty `compose/zzz-probe/` and confirm `[every-stack-is-modelled]`
  fails with exit 1; remove it.
- Temporarily point an `ac-` at a non-existent directory and confirm `[no-phantom-stacks]`
  fails with exit 1; revert.
- `git commit` with a staged `architecture/` change exercises `.githooks/pre-commit`
  unchanged.
- The `add-service` skill is verified by use, not by a test — the next real service addition
  is its first trial, and the reason the other four skills are deferred until then.

## Sequencing

`CLAUDE.md` and the validator change are independent of each other. The skill should be
written last, so it can cite the validator rule names as they actually exist.
