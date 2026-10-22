---
name: update-integration-matrix
description: Keep README's Plugins table aligned with nullkomma's implementation when adding, changing or removing plugins, tools, checks, templates, files, editor integration or CI behavior.
---

# Updating the Plugins table

Update `README.md`'s **Plugins** table from the implementation, not from
proposals or assumptions about upstream tools.

1. Find every `plugins.<name>` definition for the affected plugins; one
   plugin may span several files.
1. Note what enabling the plugin adds. If the source is unclear, evaluate a
   fixture the way `modules/dev/tests.nix` does and compare it enabled vs disabled.
1. Update only the affected cells, briefly. Each column is an output of the
   project's flake: list what the plugin adds there (check names, package
   names, tasks, dev-shell tools, treefmt programs). Leave a cell empty only
   when the plugin adds nothing there. Never list unimplemented plugins.
1. Files the plugin writes (source-of-truth or generated), editor settings and
   how to configure them go in the plugin's section under **Plugin details**,
   not the table.
1. Run `nix fmt` and review the diff.
