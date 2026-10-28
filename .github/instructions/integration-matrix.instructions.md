---
applyTo: modules/**/*.nix,templates/**,README.md,.github/workflows/ci.yml
---

When changing what a plugin adds, use
[update-integration-matrix](../../modules/dev/_skills/update-integration-matrix/SKILL.md) to keep
README's **Plugins** table in sync. Leave the table alone if behavior is unchanged.

Plugins never read each other's options or import each other (README's
**Design**); shared values are framework options any plugin may set or read.

Templates only select plugins and options; files that depend on configuration
come from `nk-write-files` or `nk-generate-files`. Never overwrite an edited
source-of-truth file; use the nk-resolve-file-conflicts skill.
