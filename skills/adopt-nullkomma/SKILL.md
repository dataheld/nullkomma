---
name: adopt-nullkomma
description: Set up nullkomma (Nix devshells, formatters, checks, tasks, CI and agent instructions) in a project that does not use it yet.
---

# Adopting nullkomma

Use this only in a project without a nullkomma `flake.nix`.
Once nullkomma is set up, the project's `AGENTS.md` and
`.agents/skills/nullkomma-*` replace this plugin.

1. Read the "Getting started" section of
   [nullkomma's README](https://github.com/dataheld/nullkomma#getting-started)
   and follow it; it is the source of truth for these steps.
   Do not copy files from the nullkomma repository by hand.
1. Ask the user which optional plugins (for example `r` or `quarto`)
   the project needs, and set them in `flake.nix` .
3. Carefully investigate the remainder of the repo. Is there anything that is no longer needed because it is now provided for by nullkomma?
1. Run `nix develop --command tasks all` and fix what fails.
1. Commit `flake.nix`, `flake.lock`, `.envrc`
   and the source-of-truth files `nk-write-files` wrote.

Remember that the point of nullkomma is to minimize boilerplate in a user's source. So adopting nullkomma should usually result in *fewer* lines of codes.