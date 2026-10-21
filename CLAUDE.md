# localserver-config (agent notes)

Owner-only infra repo for the homelab host. Agents read it and must get explicit permission to write to it.

## Require explicit approval - they contact the graph or the host over ssh and therefore impact production data
`scripts/arch-export.sh`, `scripts/arch-sync-export.sh`, `scripts/provisioning-sync.sh`,
`scripts/hla`, `scripts/deploy-*.sh`, `ssh`, `scp`. If one is needed, tell the owner the impact and wait for their approval.

## Generated files: never hand-edit
`architecture/export.json`, `architecture/model.yaml`, `architecture/metamodel.yaml`,
`architecture/overview.html`. The only hand-edited architecture files are
`architecture/provisioning/*.yaml`.

## Rules
- `git commit --no-verify`: only for WIP commits that do not touch `architecture/`; the
  pre-commit hook is the gate.
- Provisioned (YAML) facts: on a component `name`, `description`, `stack`, `image`, `source`,
  `routing`, and the links `provides`, `deployed_on`, `depends_on`, `exposed_via`.
- Graph-owned facts are proposals to the graph (a curation session in homelab-model proposes,
  the owner approves), never YAML: `pillar_exemption`, `plain_language` and `lifecycle` on a
  component; the pillar edges `primarily_serves` / `also_serves` / `enables`; controls;
  risks and gaps; data entities. Do not copy them into the provisioning files.
- Commit provisioning YAML and the regenerated `architecture/` together.

## Lifecycle docs
- `~/dev/homelab-arch/docs/change-playbook.md`: #sync-map (what comes from where),
  #4-provisioning-facts-and-infra (add or change), #5-retire-or-rename (retire or rename).
- `docs/ADD-SERVICE.md` section 10: ordered deploy, provisioning-sync, arch-export, commit.
