---
name: update-integration-matrix
description: Keep README's plugin integration matrix aligned with nullkomma's implementation when adding, changing or removing plugins, tools, checks, templates, files, editor integration or CI behavior.
---

# Updating the integration matrix

Maintain `README.md`'s **Plugins and integrations** section from the
implementation, not from proposals or assumptions about upstream tools.
Keep the matrix curated; do not add a metadata registry or documentation generator.

## Procedure

1. Read the current matrix and identify the affected exported `plugins`.
   Follow contributions across all files defining each plugin, its
   imported modules and any explicit interactions with other plugins.
1. Trace the changed behavior through the shared interfaces linked below the
   matrix. Separate consumer configuration from `modules/dev`'s internal
   development environment and tests.
1. Establish the `base` plugin's baseline and what an optional import adds. When source
   alone is insufficient, evaluate the existing consumer fixtures, using the
   debug configuration pattern in `modules/dev/tests.nix` to inspect options.
   Compare baseline and baseline-plus-import with the same system and overrides.
   Do not add a public API just to inspect documentation.
1. Update the affected cells with short descriptions of additions, not a full
   inventory of inherited defaults. Identify the actual exported import in
   each row. Keep integrations grouped in the existing columns; explain a new
   column only when a genuinely distinct consumer concern warrants it.
1. State conditions and limitations: default versus opt-in, project type,
   platform availability, or combinations of imports. Use `None` only for a
   verified absence of an added integration, not unknown behavior. Do not put
   speculative or unimplemented rows in the README.
1. Check each changed claim against source and relevant consumer contracts.
   Update behavioral tests when behavior changes; documentation edits alone do
   not require new tests. Run the existing Markdown formatting checks and review
   additions and removals before finishing.

## Accuracy rules

- A plugin is an exported module; a column is an integration it contributes to.
  A source file is not necessarily an independently selectable plugin.
- Treefmt support for a language does not mean nullkomma exports a project-type
  plugin for that language.
- Distinguish an exposed package from a check that actually builds/verifies it.
  An extension point without a supplied implementation is not an active build.
- Distinguish formatter/linter configuration, editor integration and an installed
  language-server executable. An extension recommendation does not install it.
- Distinguish files copied by templates, files initialized if missing, user-owned
  project configuration and artifacts generated during a build.
- Personal editor/user environment policy belongs outside nullkomma.
- Check conditional behavior and explicit cross-plugin integration; option
  merging is not proof that every combination works.
- Do not fill an empty cell by implementing an unrequested feature.

The matrix summarizes consumer defaults, not every possible configuration.
This skill and the path-scoped reminder reduce drift; they do not provide a
deterministic CI guarantee. Keep source links, behavioral tests and human review
as the evidence for each claim.
