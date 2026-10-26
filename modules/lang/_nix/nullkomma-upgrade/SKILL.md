---
name: nullkomma-upgrade
description: Upgrade this project to the latest nullkomma (and its other flake inputs), resolve file conflicts and verify the result.
---

# Upgrading nullkomma

1. Start from a clean Git working tree.
1. Run `update`, or `update nullkomma` to update only nullkomma.
   It updates `flake.lock`, then runs `nk-write-files` and `nk-generate-files`.
1. If `nk-write-files` reports conflicts,
   use the nullkomma-resolve-file-conflicts skill.
1. Reload the dev shell (`direnv reload`) so later commands use the new version.
1. Run `tasks all` and fix what fails.
   For breaking changes, read nullkomma's README and commit log
   between the old and new revisions in `flake.lock`.
1. Commit `flake.lock` and the updated files together.
