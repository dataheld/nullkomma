---
name: nk-adopt
description: Set up nullkomma (Nix devshells, formatters, checks, tasks, CI and agent instructions) in a project that does not use it yet.
---

# Adopting nullkomma

Use this only in a project without a nullkomma `flake.nix`.
Once nullkomma is set up, the project's `AGENTS.md` and
`.agents/skills/nk-*` replace this plugin.

1. Read the "Getting started" section of
   [nullkomma's README](https://github.com/dataheld/nullkomma#getting-started)
   and follow it; it is the source of truth for these steps.
   Do not copy files from the nullkomma repository by hand.
1. Ask the user which optional plugins (for example `r` or `quarto`)
   the project needs, and set them in `flake.nix`.
1. For workflows that publish to FlakeHub or use FlakeHub Cache, ensure the
   relevant jobs have `permissions: id-token: write`. FlakeHub uses GitHub
   Actions OIDC for authentication; private flakes and cache paths also require
   access to be granted in FlakeHub.
1. Investigate the rest of the repository:
   remove what nullkomma now provides.
1. Run `nix develop --command nk all`,
   then `nix flake check`, and fix what fails.
1. Commit `flake.nix`, `flake.lock`, `.envrc`
   and the source-of-truth files `write-files` wrote.

The point of nullkomma is to minimize boilerplate in a project's sources.
So adopting nullkomma should usually result in *fewer* lines of code.
