---
name: nk-upgrade
description: Upgrade this project to the latest nullkomma (and its other flake inputs), resolve file conflicts and verify the result.
---

# Upgrading nullkomma

1. Start from a clean Git working tree.
1. Run `nk flake-update`, or `nk flake-update nullkomma` to update only nullkomma.
   It updates `flake.lock`, then runs `write-files` and `generate-files`.
1. If `nk write-files` reports conflicts,
   use the nk-resolve-file-conflicts skill.
1. Check the project's *existing* nullkomma configuration
   for deprecations and updates.
   An upgraded nullkomma often fixes something
   that previously required a workaround in the project.
   If you are uncertain, set up nullkomma *again*
   in an isolated temporary directory and compare it with this project.
   For each difference: is it still needed?
   Does nullkomma now do this by default, or offer a more concise way?
1. Reload the dev shell (`direnv reload`) so later commands use the new version.
1. Run `nk all`, then `nix flake check`, and fix what fails.
   For breaking changes, read nullkomma's README and commit log
   between the old and new revisions in `flake.lock`.
1. Commit `flake.lock` and the updated files together.

Do not update `README.md` or otherwise record the upgrade in the repository;
report it to the user instead.

The point of nullkomma is to *reduce* its footprint in the project's sources:
this makes upgrades easier and leaves less to distract or drift.
