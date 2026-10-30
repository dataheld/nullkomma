# Agent notes

## Check flake.parts first

nullkomma is a set of [flake-parts](https://flake.parts) modules. Before
building or changing anything, check whether flake-parts or an existing
flake-parts module already solves it:

1. Read the relevant pages on <https://flake.parts>, including the guides and
   the `flake-parts-lib` helpers (e.g. `mkTransposedPerSystemModule`,
   `importApply`, `importAndPublish`) and the optional extras (`flakeModules`,
   `modules`, `partitions`, `touchup`, …).
1. Search the module catalog: the sidebar of <https://flake.parts>, and
   `render.inputs` in
   [flake.parts-website's `flake.nix`](https://github.com/hercules-ci/flake.parts-website/blob/main/flake.nix),
   which lists more modules than the menu shows.
1. Read the source when docs are thin; it's usually short.

Prefer an existing module, then contributing upstream, then writing our own.
Every new input lands in every consumer's `flake.lock`; dev-only inputs go in
[`dev/flake.nix`](dev/flake.nix) (the `dev` partition's `extraInputsFlake`).

### Decisions so far

| Module                                                                          | Decision                                                                                                                           |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| treefmt-nix                                                                     | used, imported by the framework                                                                                                    |
| [process-compose-flake](https://flake.parts/options/process-compose-flake.html) | used: defines all tasks and process trees; up is kept only for its flake schemas                                                   |
| flake-parts `flakeModules`, `modules`, `partitions`                             | used for exports and dev-only evaluation                                                                                           |
| nix-unit                                                                        | not its flake module: the `nix` plugin runs `pkgs.nix-unit` itself, so projects get no extra input                                 |
| [files](https://flake.parts/options/files.html)                                 | not used: its files are generated _and committed_; ours are user-owned (3-way updates or marked sections) or generated and ignored |
| [devshell](https://flake.parts/options/devshell.html)                           | not used: own builder and command menu overlap with up tasks                                                                       |
| [make-shell](https://flake.parts/options/make-shell.html)                       | not used: would add a consumer input for ~30 lines of `mkShell` wrapper                                                            |
| [std](https://flake.parts/options/std.html)                                     | not used: heavy framework with many inputs                                                                                         |
| [mission-control](https://flake.parts/options/mission-control.html)             | not used: deprecated; tasks use process-compose-flake                                                                              |

Revisit these when the module or our needs change.

### Publishing upstream

nullkomma exports `flakeModules.<plugin>`, `flakeModules.framework` and
`flakeModules.default` (also as `modules.flake.*`), and the `options-doc` check
renders their options the way flake.parts does. Listing nullkomma on
flake.parts takes a PR adding it to flake.parts-website's `render.inputs`.

Candidates for upstreaming instead of keeping here:

- typed process-compose `watch` and MCP options in
  [process-compose-flake](https://github.com/Platonic-Systems/process-compose-flake)
  (#276, #277), and the `taskRunners`/`processTrees` schemas in
  [flake-schemas](https://github.com/DeterminateSystems/flake-schemas) (#278);
- source-of-truth/generated file modes in
  [mightyiam/files](https://github.com/mightyiam/files);
- editor-neutral language servers (`nullkomma.editor`) as a standalone module.

## Patching upstream tools

Keep behavior patches as `patches/<tool>.patch`, applied through `overrideAttrs`
`patches`; temporary fixes for upstream breakage may stay inline.
Linter configuration lives in Nix. Reuse treefmt-nix options, generate any required
config files in the Nix store and pass them explicitly; disable native discovery.
Don't patch tools to merge shared and project configuration.

## Stay vanilla

Generated sites use stock Quarto and Bootstrap: set options only to switch on
features, and leave layout, spacing and styling to Quarto's defaults and brand.yml.
Don't restate defaults, and add custom CSS only for what neither offers. Check
rendered pages on narrow and wide screens before changing presentation.

<!-- nullkomma:agents:start -->
## nullkomma

This project's development environment comes from [nullkomma](https://github.com/dataheld/nullkomma).
Run commands inside its dev shell:
`direnv exec . <command>`, or `nix develop --command <command>` without direnv.
`nk` lists the project's workflows;
`nk <name> [args]` runs one.
Agents can also use them as MCP tools, from `.mcp.json`.

Check your work locally, from fastest to strictest:

1. While you work, run the narrowest task that covers the change,
   e.g. `nk nk-r-test`.
1. Before you report a change as done, run `nk all`, then `nix flake check`,
   and fix what fails.
   `nk all` formats, regenerates files and runs the checks in the working tree.
   `nix flake check` runs the checks sandboxed, as CI does,
   and sees only files that Git tracks: `git add` new files first.

Skills for nullkomma itself are in `.agents/skills/nk-*`;
if they are missing, run `nk nk-generate-files`.
<!-- nullkomma:agents:end -->
