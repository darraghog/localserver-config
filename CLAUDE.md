# localserver-config (agent notes)

Owner-only infra repo for the homelab host. Agents read it and must get explicit permission to write to it.

## Rules
- `git commit --no-verify`: only for WIP commits that do not touch `architecture/`; the pre-commit hook is the gate.
