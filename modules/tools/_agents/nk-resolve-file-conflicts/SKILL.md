---
name: nk-resolve-file-conflicts
description: Review and resolve nullkomma file-update conflicts after upgrades, preserving the project's edits to source-of-truth files.
---

# Resolving file conflicts

Run `nk-write-files` to get the current conflicts and candidate paths.
Do not overwrite edited source-of-truth files or silently accept all baselines.

## Source-of-truth files

1. Read the current file, the incoming candidate and, if present, the old
   baseline. Their paths are printed by `nk-write-files`; state lives under
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
   run `nk-write-files --accept <path>` for that file. This
   acknowledges the current upstream initializer without overwriting the project
   file. Do not accept changes you have not reviewed.
1. Rerun `nk-write-files`, inspect the Git diff, and run `tasks all`.
   Commit the changes as usual. Baselines are local Git metadata,
   not committed files; a new clone may need review again.

## Files generated from Nix

These never conflict: `nk-generate-files` overwrites them. To keep a change, make it
in the Nix options instead. Generation refuses symlinks and non-regular targets;
investigate rather than removing them automatically.
