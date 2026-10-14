---
applyTo: modules/**/*.nix,templates/**,README.md,.github/workflows/ci.yml
---

When changing consumer-facing integrations or their documentation, use
[update-integration-matrix](../skills/update-integration-matrix/SKILL.md) to check
and update README's **Plugins and integrations** matrix alongside the
change. If behavior is unchanged, do not invent a matrix update.

Follow README's **Neutral interfaces between plugins** contract when connecting
plugins. Put shared contracts in the framework; prefer standard flake outputs.
Consumers must not inspect producer plugin flags or import a specific producer
when a neutral artifact suffices. Document shape, selection, absence and
validation; reject missing required inputs explicitly. Test interchangeable
producers without unrelated plugins, plus real tool success/failure separately.
Do not add speculative deployment/caching APIs or a universal artifact registry.

Template variants are starting presets, not separate file-generation engines:
select plugins/options in their flakes and retain `nix run .#write-files` as the
configuration-aware initializer. Avoid duplicating configuration-derived files.
