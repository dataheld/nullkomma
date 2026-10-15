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
1. Update only the affected cells, briefly. Mark formatter/linter coverage with
   ✅; tool names stay in the source. Leave a cell empty only when the plugin
   adds nothing there. Never list unimplemented plugins.
1. Keep the distinctions the columns make: a recommended extension is not an
   installed tool; a source-of-truth file is not a generated one.
1. Run `nix fmt` and review the diff.
