---
name: resolve-file-conflicts
description: Review and resolve nullkomma file-update conflicts after upgrades, preserving project-owned edits and keeping local generated configuration in Nix.
---

# Resolving file conflicts

Use this in the affected consumer repository, not the nullkomma checkout.
Run `nix run .#write-files` to get the current conflicts and candidate paths.
Do not force regeneration of shared files or silently accept all baselines.

## Shared, project-owned files

1. Read the current file, the incoming candidate and, if present, the old
   baseline. Their paths are printed by `write-files`; state lives under
   `$(git rev-parse --git-path nullkomma/files)`. Never treat the baseline as
   the project's source of truth.
1. Explain the upstream changes and the project edits. With a baseline, a
   three-way merge can help (`git merge-file -p current baseline incoming`);
   inspect its output and exit status rather than writing it directly over the
   current file. Without a baseline, compare current and incoming explicitly;
   do not guess which local differences were intentional.
1. Preserve project intent, incorporating applicable upstream changes. Ask the
   user about substantive ambiguities. Review workflows for permissions,
   credentials and execution changes. Never copy secrets into reports.
1. After resolution (including a deliberate decision to retain project content),
   run `nix run .#write-files -- --accept-shared <path>` for that file. This
   acknowledges the current upstream initializer without overwriting the project
   file. Do not accept changes you have not reviewed.
1. Rerun `write-files`, inspect the Git diff, and run the relevant checks.
   Commit the shared-file changes as usual. Baselines are local Git metadata,
   not committed files; a new clone may need review again.

## Generated, Nix-owned local files

Read the local file and compare it with the generated candidate. Move useful
edits into the appropriate Nix options, then run
`nix run .#generate-files` and approve replacement after explaining any loss.
Use `--yes` only with explicit authorization for unattended replacement.
Do not merge edits back into a generated file: its warning and local Git ignore
are deliberate, and its ultimate source of truth is Nix.

If generation refuses a tracked file, do not untrack it automatically. Preserve
its useful content in Nix and get approval before `git rm --cached -- <path>`.
Generation refuses symlinks and non-regular targets; investigate rather than
removing them automatically.
