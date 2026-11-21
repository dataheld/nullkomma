---
name: nk-adopt
description: Set up nullkomma (Nix devshells, formatters, checks, tasks, CI and agent instructions) in a project that does not use it yet.
---

# Adopting nullkomma

Use this only in a project without a nullkomma `flake.nix`.
Once nullkomma is set up, the project's `AGENTS.md` and
`.agents/skills/nk-*` replace this plugin.

1. Find out whether other flakes have this project as an input,
   for example for its `lib`, modules or packages.
   Ask the user if the repository does not show it.
1. Follow the "Getting started" section of
   [nullkomma's README](https://github.com/dataheld/nullkomma#getting-started).
   If other flakes have this project as an input, follow its
   [Development-only inputs](https://github.com/dataheld/nullkomma#development-only-inputs)
   instead of the template: nullkomma goes only into `dev/flake.nix`.
   Do not copy nullkomma's files from its repository.
1. Ask the user which optional plugins (for example `r` or `quarto`)
   the project needs, and set them in `flake.nix`.
1. Investigate the rest of the repository:
   remove what nullkomma now provides.
1. Run `nix develop --command nk all`,
   then `nix flake check`, and fix what fails.
1. Commit `flake.nix`, the lock files, `dev/` if there is one,
   and the project files `write-files` created.

The point of nullkomma is to minimize boilerplate in a project's sources.
So adopting nullkomma should usually result in *fewer* lines of code.
