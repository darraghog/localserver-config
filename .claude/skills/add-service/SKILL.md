---
name: add-service
description: Use when adding, changing or retiring a service stack in localserver-config (new compose stack, port, image, routing, Caddy exposure, or an entry in architecture/provisioning/*.yaml).
---

# Add, change or retire a service

First invoke the `homelab-change-lifecycle` skill (homelab-arch-routing plugin) if it is
available. This repo is owner-only: agents read it and never write to it without permission. When asked to help,
you default to being a guide for the owner: list the files and the exact YAML and compose changes, then hand
over. Unless explicitly asked, you do not scaffold, edit files or create proposals from this session. If asked, ensure the owner is aware of the implications of the change.
The full procedure is `docs/ADD-SERVICE.md` (section 10 for the model). The lifecycle lives in
`~/dev/homelab-arch/docs/change-playbook.md` (sections `#4-provisioning-facts-and-infra` and
`#5-retire-or-rename`); do not restate or reorder it.

## What to hand the owner or request permission from owner for
- The files to touch: `compose/<name>/`, the Caddy and TLS changes of `docs/ADD-SERVICE.md`
  sections 1 to 9, and `architecture/provisioning/*.yaml`.
- The exact YAML (below) and compose text, written out in your reply.
- OWNER: scaffold with `./scripts/add-service.sh <name> --port N [--container-port PORT] --image IMG`
  (lowercase letters, digits, hyphen; built-ins `hello-world`, `n8n`, `tls-proxy` are refused).

## What goes where (ADD-SERVICE section 10)
In `architecture/provisioning/*.yaml` (the owner edits or approves edits):
- `ApplicationComponent` `ac_<name>`: name, description, stack, image, routing
  (`strip` | `no-strip` | `not-path-mounted`), and `source` (repo that owns the app, or
  `in-repo`) when the image is locally built.
- `ApplicationService` `as_<name>`: `provides` from the component and exactly one
  `exposed_via`.

Graph-owned, never in the YAML: `primarily_serves` (exactly one pillar) / `also_serves` /
`enables`, or `pillar_exemption`; `lifecycle`, `plain_language`, controls, data entities.
A curation session (homelab-model) proposes the graph-owned facts (playbook section 3,
`dry_run` first); the owner approves. Name them in your hand-over; do not propose them here.

Red flag: never edit `architecture/model.yaml` or any file in `architecture/` other than
`provisioning/*.yaml`. They are generated; hand edits are overwritten and fail the hook.

## Order (deploy first, commit last)
1. OWNER: edit compose and the provisioning YAML; do not commit yet.
2. OWNER: `./scripts/deploy-service.sh prod beeblebox <service>`.
3. OWNER: `scripts/provisioning-sync.sh --check`, then `scripts/provisioning-sync.sh`.
4. A curation session (homelab-model) proposes the graph-owned facts; the owner approves.
5. OWNER: `scripts/arch-export.sh`, review `git diff architecture/`, commit the YAML and
   `architecture/` together. The pre-commit hook passes only now.

`git commit --no-verify`: only for WIP commits that do not touch `architecture/`. If the hook
refuses, follow the recovery steps it prints.

## Retire or rename (playbook #5)
Provisioning sync refuses to remove an entity that still has graph-owned edges or properties,
and sees them only once the entity is gone from the deployed YAML.
1. A curation session reads them (`neighbours`, `get_entity`), proposes `delete_edge` for each
   graph-owned edge and clears the graph-owned properties; the owner approves.
2. OWNER: remove the entity from the YAML and deploy (`./scripts/deploy-service.sh`).
3. OWNER: `scripts/provisioning-sync.sh --check` names what still blocks (exit 1, `ERROR`
   lines); exit 4 means only the removal itself is pending.
4. OWNER: `scripts/provisioning-sync.sh`, `scripts/arch-export.sh`, commit together, then
   `~/dev/homelab-arch/scripts/verify-deployment.sh`.
A rename is remove plus add: carry the graph-owned edges over in the same sitting.

## Agent limits
Request owner permission to write to this repo (including scaffolding, file edits and commits) and never create proposals
from this session unless specifically asked.  Ask permission to run deploy-service, provisioning-sync, arch-export, arch-sync-export,
`hla`, `ssh` or `scp`; indicate the impact of the change to the owner before running. Report the ids, class, properties, the YAML text and the
next owner step.
