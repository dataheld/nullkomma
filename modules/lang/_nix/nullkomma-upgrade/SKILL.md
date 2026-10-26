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
4. Check *existing* nullkomma configuration for deprecations or updates. Frequently, an upgraded nullkomma will fix something that previously required a workaround in a user package. If you're uncertain, the best way is to set up nullkomma *again* (in an isolated temporary directory) and check how your current instantiation is different. Check any differences you find: are they still needed? Does nullkomma maybe do this now out of the box or offer a more concise way to do it?  
5. Reload the dev shell (`direnv reload`) so later commands use the new version.
6. Run `tasks all` and fix what fails.
   For breaking changes, read nullkomma's README and commit log
   between the old and new revisions in `flake.lock`.
7. Commit `flake.lock` and the updated files together.

There is no need for you to update the `README.md` manually or record what you did otherwise in the git repo, though you can report it back to the user.

Remember, the point of nullkomma is always to *reduce* it's footprint in the user's sources, so that upgrading is easier, there is less distraction and chance for drift.
