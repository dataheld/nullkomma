# nullkomma ⚡️❄️

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/dataheld/nullkomma/badge)](https://flakehub.com/flake/dataheld/nullkomma)

extra-[DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) 🤌,
maximally transparent 🫥,
batteries-included 🔋
[Nix](https://nixos.org) ❄️
boilerplate experiment 🧪.

> nullkommanix [ɪn ˈnʊl ˌkɔma ˈnɪçt͡s] noun German colloquialism (translation: in next to time).

An ideal development environment has these criteria:

| Criterion maximized                                                                       | Design goal                                                                                                             | Positive effects                                                                    | Antipatterns avoided                                                                                                                                               |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 🤌 Extra-[DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)                     | Minimize the footprint in a project's version-controlled source; declare only a tooling version and required languages. | Lower fixed costs per project and clearer separation of concerns.                   | [The Makefile effect](https://blog.yossarian.net/2025/01/10/Be-aware-of-the-Makefile-effect): copied boilerplate causes technical debt and drift between projects. |
| 🫥 Maximum transparency, minimal [indirection](https://en.wikipedia.org/wiki/Indirection) | Minimize additional abstraction over existing tools.                                                                    | Use upstream tools directly, without changes.                                       | Wrappers whose abstraction costs exceed their benefits, adding bugs and abstraction leaks across a project.                                                        |
| 📋 Comprehensive quality gates                                                            | Enforce as many checks as possible, from linting to integration tests.                                                  | Expose all project checks and their feedback programmatically, including to agents. | Missing or poorly discoverable quality gates.                                                                                                                      |

Unfortunately, these criteria sometimes conflict.
In fact, you can only maximize two out of three, forming a kind of ["impossible trinity"](https://en.wikipedia.org/wiki/Impossible_trinity).
But if you *can* relax one of the criteria, there is already great tooling out there for you.

![A triangle comparing DRY, quality gates and transparency across development environments.](assets/development-environment-triangle.svg)

Points nearer a corner give more weight to that criterion;
points near an edge emphasize the two criteria at its ends.
The examples compare [devenv](https://devenv.sh/),
[devshell](https://github.com/numtide/devshell),
and [flake-parts](https://flake.parts/) with [treefmt](https://treefmt.com/)
against short and long vanilla flakes.
Positions illustrate relative emphasis in representative configurations,
not measured scores or limits on how these tools can be configured.

nullkomma cannot overcome these tradeoffs, but it is an attempt in achieving a higher [pareto frontier](https://en.wikipedia.org/wiki/Pareto_frontier) of these competing objectives.

## Entrypoints

A nullkomma project documents itself through the commands below.
This section explains what kind of entrypoint each is;
to see what it offers in your project, run it.

### `nk`

In the [development shell](#getting-started), `nk` lists the project's tasks,
grouped by plugin; your own tasks form the `custom` group.
`nk <task> [args]` runs one in the working tree, after its prerequisites,
and fails when any of them fails.
`nk all` formats, regenerates files, builds and runs every check.

A task is a process with a `description` in the [process-compose] `dev` tree,
so `nk <task>` runs it once, in the foreground, as `process-compose run` does.
A task that never exits, such as a preview server, runs as `process-compose up <task>`.

### `process-compose up`

In the development shell, `process-compose up` starts every process of the `dev` tree
that is not `disabled`, in a terminal UI:
the tasks that work in the working tree, rerun when their files change,
and services such as previews, which reload open pages.
Tasks that run your code on every change, such as `r-test` and `r-build-site`,
run here in their own copy of the working tree, so that files they write can't restart them.
Each logs where its copy is, keeps it until its next run,
and copies back only the outputs whose content changed, such as snapshots or the site.
`nk <task>` runs them in the working tree.
It does not run `nix flake check`:
actions such as `write-files`, tasks that need a sandbox,
and the `all` and `check` groups are disabled.
`process-compose up <process>` starts one process and its prerequisites;
`PC_DISABLED_PROCESSES=r-check process-compose up` skips some.
`up` does not report a failed task in its exit status; `nk <task>` does.
Other commands, e.g. `process-compose process logs r-test`,
reach the running tree through a per-checkout socket.

### Flake outputs and `nix`

`nix flake show` lists your flake's outputs, described by its `schemas` output.
The usual `nix` commands use them.
Tasks reuse the same processes, but run on the uncommitted working tree, for speed;
builds and checks run sandboxed, on the files Git tracks (`git add` new files first).

| Command                               | Output              | In the working tree                   | Fed by                                     |
| ------------------------------------- | ------------------- | ------------------------------------- | ------------------------------------------ |
| `nix develop`, or [direnv]            | `devShells.default` |                                       | `perSystem.nullkomma.devShell.*`           |
| `nix fmt`                             | `formatter`         | `nk treefmt`                          | `perSystem.treefmt.programs.*`             |
| `nix flake check`                     | `checks`            | `nk check`                            | `check.depends_on.*` in the `dev` tree     |
| `nix build .#site`                    | `packages.site`     | `nk quarto-render`, `nk r-build-site` | `perSystem.packages.site`                  |
| `nix run .#<app>`                     | `apps`              |                                       | `perSystem.apps.*`                         |
| `nix run .#processTrees.<system>.dev` | `processTrees`      | `process-compose up`                  | `perSystem.process-compose.dev.settings.*` |
|                                       | `taskRunners`       | `nk`                                  | processes with a `description`             |
| `nix flake update`                    | (`flake.lock`)      | `nk flake-update`                     |                                            |

`nk flake-update` also runs `write-files` and `generate-files`;
after another `nix flake update`, e.g. by a bot, run those two yourself.

### MCP servers and skills

The [`agents`](#agents) plugin generates two things that coding agents read,
from your `flake.lock`, so they match the nullkomma you use:

- `.mcp.json` lists [MCP] servers.
  `nullkomma` (`nk mcp`) serves the tasks as tools,
  and process-compose's own tools to start, stop and read the logs of services.
  It runs its own process-compose instance, not the one of an interactive `process-compose up`.
  Plugins add servers for their tools (see the MCP column under [Plugins](#plugins)).
  The agent starts each server when it needs it, so they are not processes of the `dev` tree.
  Stdio servers start in the development shell (`nix develop --command`),
  so they and the processes they start see its environment.
- `.agents/skills/` holds [Agent Skills](https://agentskills.io), named `nk-*`.

This repository is also an [Agent Plugin](https://agent-plugins.org):
in a project without nullkomma, its nk-adopt skill adds nullkomma,
e.g. after `/plugin install https://github.com/dataheld/nullkomma` in Copilot.

## Getting started

### Prerequisites

1. Install Nix; the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer) is recommended.
   On Windows, use the [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install).
1. For automatic shell activation, install [direnv] and [nix-direnv] in your user environment,
   e.g. with [lap](https://github.com/dataheld/lap).
   Set [`hide_env_diff = true`](https://direnv.net/man/direnv.toml.1.html) to quiet it.

Everything else comes from your project's flake.

### Adding nullkomma to a project

In your project, with a clean working tree, run:

```sh
nix flake init --template "https://flakehub.com/f/dataheld/nullkomma/0.1.*#default"
git add flake.nix
nix develop --command nk write-files
nix develop --command nk generate-files
git add -A
git commit -m "add nullkomma"
direnv allow
```

The template adds `flake.nix`, keeping existing files;
`write-files` and `generate-files` add the [files](#files-in-your-repository) that depend on your configuration.
The template's `nixpkgs.follows = "nullkomma/nixpkgs"` uses nullkomma's tested Nixpkgs.
To use your own, declare `nixpkgs.url` and set `nullkomma.inputs.nixpkgs.follows = "nixpkgs"`.
After editing your Nix files, run `direnv reload`.

## Configuring

`nullkomma.lib.mkFlake` is flake-parts' `mkFlake` with every plugin imported and the default ones enabled,
so you list only exceptions and options.
The template imports every `*.nix` file under `nix/` as a flake-parts module:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  imports = inputs.nullkomma.lib.importTree ./nix;
}
```

To configure a plugin, write all its options, commented out at their defaults with their descriptions,
into a file of their own:

```sh
nix eval --raw --inputs-from . nullkomma#lib.configs.r > nix/r.nix
```

### Development-only inputs

Flakes that consume yours lock your inputs, and may fetch them.
Declare inputs that only your development needs, such as a private [brand](#brand),
in a second flake, `dev/flake.nix`, lock it with `nix flake lock ./dev`,
and use them in a `dev` [partition](https://flake.parts/options/flake-parts-partitions.html):

```nix
partitions.dev = {
  extraInputsFlake = ./dev;
  module = { inputs, ... }: { nullkomma.brand = inputs.brand; };
};
```

nullkomma then takes per-system outputs, such as `packages` or `checks`, from the partition.

If other flakes consume yours, keep nullkomma itself in that partition too,
but leave `schemas` out of `partitionedAttrs`, and `apps` too if the partition has none:
most `nix` commands read `schemas` to resolve `.#name`, and `nix run` searches `apps`.
Nix's default schemas then list `processTrees`, `taskRunners` and `tests` as unknown.

### Linting

Configure linters in Nix, not in config files.
Native config files are ignored (Jarl, which can't ignore them, fails instead);
suppression comments such as `# shellcheck disable=SC2086` still work.
Your settings override plugins' `lib.mkDefault` values, and lists concatenate.
typos, rumdl (`markdown`), actionlint, gitleaks, jscpd, Ruff and ty take their settings
from `nullkomma.lint.<tool>`; the others from treefmt-nix:

| Linter        | Nix configuration                                   | Settings                                                 |
| ------------- | --------------------------------------------------- | -------------------------------------------------------- |
| yamllint      | `perSystem.treefmt.programs.yamllint.settings`      | yamllint's YAML config                                   |
| ShellCheck    | `perSystem.treefmt.programs.shellcheck`             | treefmt-nix options, e.g. `severity`                     |
| deadnix       | `perSystem.treefmt.programs.deadnix`                | treefmt-nix switches, e.g. `no-lambda-arg`               |
| nixf-diagnose | `perSystem.treefmt.programs.nixf-diagnose`          | treefmt-nix options, e.g. `ignore`                       |
| Jarl          | `perSystem.treefmt.settings.formatter.jarl.options` | CLI arguments, e.g. `[ "--ignore=any_is_na" ]`           |

`perSystem.treefmt.settings.excludes` skips files for every tool, jscpd included;
see [treefmt-nix's options](https://flake.parts/options/treefmt-nix.html).
Generated files aren't formatted or linted;
add other generated content to `nullkomma.generatedPaths` as treefmt globs.

### Tasks and checks

Add tasks as [process-compose-flake] processes of the `dev` tree.
A process that `check` depends on is a check:
`nk check` runs it in the working tree, and `checks.<name>` sandboxed.
`nullkomma.sandbox { process, args ? [ ], output ? null }`
runs a process in a writable copy of the flake's source (`nullkomma.src`), for checks and packages:

```nix
perSystem = { config, pkgs, ... }: {
  process-compose.dev.settings.processes = {
    report = {
      description = "Render the report";
      disabled = true; # on request only, not in `process-compose up`
      command = "${pkgs.quarto}/bin/quarto render report.qmd";
      watch = [ { paths = [ "report.qmd" ]; } ];
    };
    check.depends_on.report.condition = "process_completed_successfully";
  };
  packages.report = config.nullkomma.sandbox { process = "report"; output = "_report"; };
};
```

Tasks that `nix flake check` can't run, e.g. because they need network, join `all` instead: `all.depends_on.<name>`.
Use process-compose's own settings, such as
[`watch`](https://f1bonacc1.github.io/process-compose/launcher/#watching-files) (`cascade = true` also reruns dependents),
`readiness_probe` and `availability`;
a task's own `mcp` block, e.g. `mcp.type = "resource"`, changes how `nk mcp` serves it.
Change plugins' tasks with ordinary module merging, e.g. `lib.mkForce` on a `command`;
builds and checks then use the changed task too.
A flake-parts module outside nullkomma can add tasks the same way.

### Brand

Sites built by [`quarto`](#quarto) or [`r`'s pkgdown](#pkgdown-website) can take their theme from a brand flake exposing `lib.brand`
(a [brand.yml]), once you enable the plugin's `brand.enable`:

```nix
inputs.brand = {
  url = "github:example/brand";
  inputs.nullkomma.follows = "nullkomma";
};
# Inside mkFlake's module:
nullkomma.brand = inputs.brand;
```

In a flake that other flakes consume, make the brand a [development-only input](#development-only-inputs).
An optional `defaults.nullkomma.footer` record in the brand supplies footer facts to both:

```yaml
meta:
  name: Example
  link:
    home: https://example.org
    imprint: https://example.org/imprint
    email: mailto:hello@example.org
defaults:
  nullkomma:
    footer:
      tagline: A short description
      links:
        - text: Imprint
          link: imprint
        - text: Privacy
          privacy: true
      social:
        - text: Email
          link: email
          icon: envelope
```

Each `link` names an entry of `meta.link`; `privacy: true` links to the privacy policy.
`icon` is a [Bootstrap Icon](https://icons.getbootstrap.com) name. Write plain text only.

### Privacy policy

Plugins that process visitors' data, such as `cloudflare`, add a section to `nullkomma.privacy.sections`;
so can a brand or your project:

```nix
nullkomma.privacy.sections.booking = {
  order = 500; # cloudflare is 200
  markdown = { en = ./booking.en.md; de = ./booking.de.md; };
};
```

`quarto` and pkgdown render them into one page, one tab per `nullkomma.privacy.languages`.
The sections are a starting point, not legal advice.

## Files in your repository

Features live in Nix; nullkomma writes files only where tools need them:

|                             | **Source of truth** (committed, yours to edit)       | **Generated from Nix** (Git-ignored, don't edit)                                            |
| --------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `nix flake init --template` | `flake.nix`                                          |                                                                                             |
| `write-files`               | `.envrc`, `.gitignore` and `AGENTS.md` sections, GitHub workflows, `.gitlab-ci.yml` |                                                                                             |
| `generate-files`            |                                                      | `.mcp.json`, `.vscode/*.json`, `.nvim.lua`, `.agents/skills/*`, Quarto brand and extensions |

`write-files` writes source-of-truth files (`nullkomma.files."<path>".mode = "source"`) once; then they are yours.
It keeps only their marked `sections` up to date, wherever you moved them, and strips them once nullkomma no longer declares them.
Add your own lines outside the markers, for example your jobs below nullkomma's section of `push.yml`.

`generate-files` overwrites generated files (`mode = "generated"`) when they differ from Nix,
and removes ones no longer declared; it refuses to overwrite files Git tracks.
A generated directory holds its own `.gitignore`;
a generated file must be ignored already, usually by nullkomma's `.gitignore` section, or `generate-files` does not write it and fails.
Entering the dev shell runs it; tasks never do.
To change a generated file, change the Nix options.

## Plugins

Each plugin is exported as `flakeModules.<name>`; each column is an output of your flake that it adds to.
Those marked under Default are enabled unless you opt out.

| Plugin                                                                                            | Default | `devShells`                                                                                                    | `formatter`                                | `checks`                                                  | `packages`         | `apps`                     | `taskRunners`                                                                                                                                  | `processTrees`                                                                                                                                | MCP                                             |
| ------------------------------------------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------- | ------------------ | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| framework                                                                                         | always  | `nk`, [`process-compose`][process-compose]                                                                     | [treefmt]                                  | `treefmt`; [each `check` prerequisite](#tasks-and-checks) |                    |                            | `all`, `check`, `flake-check`, `treefmt`, `write-files`, `generate-files`, `mcp`, `graph`                                                      | `dev`: `treefmt`                                                                                                                              | `nullkomma`                                     |
| [`nix`](#nix)                                                                                     | ✅       | [nixd]                                                                                                         | [`nixfmt`], [`deadnix`], [`nixf-diagnose`] | `nix-unit`                                                |                    |                            | `nix-unit`, `flake-update`, [`flake-checker`]                                                                                                  | `flake-checker`, `nix-unit`                                                                                                                   |                                                 |
| [`markdown`][md]                                                                                  | ✅       | [`rumdl`]                                                                                                     | [`mdformat`], [`rumdl`]                    |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`json`][json]                                                                                    | ✅       | [JSON language server][jsonls]                                                                                 | [`jsonfmt`]                                |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`yaml`][yaml]                                                                                    | ✅       | [yaml-language-server]                                                                                         | [`yamlfmt`], [`yamllint`], [`actionlint`]  |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`toml`][toml]                                                                                    | ✅       |                                                                                                                | [`toml-sort`]                              |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`shell`](#shell)                                                                                 | ✅       | [bash-language-server]                                                                                         | [`shfmt`], [`shellcheck`]                  | [bats]                                                    |                    |                            | `bats`                                                                                                                                         | `bats`                                                                                                                                        |                                                 |
| [`github`](#github)                                                                               | ✅       |                                                                                                                |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`gitlab`](#gitlab)                                                                               |         |                                                                                                                |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`agents`](#agents)                                                                               | ✅       |                                                                                                                |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               | `playwright` (opt-in)                           |
| [`keepSorted`][keep-sorted]                                                                       | ✅       |                                                                                                                | `keep-sorted`                              |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`gitleaks`][gitleaks]                                                                            | ✅       |                                                                                                                | `gitleaks`                                 |                                                           |                    |                            | `gitleaks-git`                                                                                                                                 |                                                                                                                                               |                                                 |
| [`typos`][typos]                                                                                  | ✅       |                                                                                                                | `typos`                                    |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`jscpd`][jscpd]                                                                                  | ✅       |                                                                                                                |                                            | `jscpd`                                                   |                    |                            | `jscpd`                                                                                                                                        | `jscpd`                                                                                                                                       |                                                 |
| [`git`][git]                                                                                      | ✅       | `git`                                                                                                          |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`direnv`][direnv]                                                                                | ✅       |                                                                                                                |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`vscode`](#editors)                                                                              | ✅       |                                                                                                                |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`neovim`](#editors)                                                                              | ✅       |                                                                                                                |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`flakehub`][flakehub]                                                                            | ✅       | [`fh`]                                                                                                         |                                            |                                                           |                    |                            |                                                                                                                                                |                                                                                                                                               |                                                 |
| [`quarto`](#quarto) (includes nkdocs; optional [brand](#brand))                                   |         | [`quarto`]                                                                                                     |                                            |                                                           | `site`             |                            | `quarto-render`, `quarto-preview`                                                                                                              | `quarto-preview`                                                                                                                              | `playwright`                                    |
| [`cloudflare`](#cloudflare)                                                                       |         | [`wrangler`]                                                                                                   |                                            | `cloudflare-validate` ([OpenTofu] validation)             |                    | `deploy`[^deploy]          | `cloudflare-validate`, `cloudflare-plan`, `cloudflare-deploy`                                                                                  |                                                                                                                                               | `cloudflare-api`, `cloudflare-docs`, `opentofu` |
| [`python`](#python)                                                                               |         | [Python], [uv], [ty], editable package with its dependency groups and extras                                   | [`ruff-check`][ruff], `ruff-format`        | `python-lock-check`, `python-test`, `python-typecheck`    | `default`, `dist`  | `<script>`, `python-lock`  | `python-lock`, `python-lock-check`, `python-test`, `python-typecheck`                                                                          | `python-lock-check`, `python-test`, `python-typecheck`                                                                                        |                                                 |
| [`r`](#r) (optional [non-Nix collaboration](#r-development-without-nix), [pkgdown brand](#brand)) |         | [R], [radian], [Air]; [languageserver], [`pkgload`], [pak], [httpgd], [later], [rstudioapi], [btw], [mcptools] | `air`, [`jarl`][jarl]                      | `r-document-namespace`, `r-test`, `r-check`               | `site` ([pkgdown]) | `r-lock`, `shiny` (opt-in) | `r-document-namespace`, `r-document`, `r-test`, `r-check`, `r-build-site`, `r-preview-site`, `r-test-coverage`, `r-lock`, `r-run-app` (opt-in) | `r-document-namespace`, `r-document`, `r-test`, `r-check`, `r-build-site`, `r-preview-site`, `r-test-coverage`, `r-shiny-<function>` (opt-in) | `r` ([btw], [mcptools]); `playwright` (Shiny)   |

Plugins meet only through framework options, so one could live in a flake of its own,
exporting its `flakeModules.<name>` with its own tasks and inputs.

Each block below is `lib.configs.<plugin>`, as [written into `nix/`](#configuring);
plugins without options beyond `enable` have none.

### `nix`

Ignores `result`.

<!-- nullkomma:nix:start -->
```nix
{
  # Whether to enable the nix plugin.
  nullkomma.nix.enable = true;

  # Whether the sandboxed nix-unit run may fetch, e.g. inputs of inputs.
  # perSystem.nullkomma.nix.unit.allowNetwork = false;

  # Inputs passed to nix-unit's sandboxed evaluation with `--override-input`, so
  # it needn't fetch them. Default: the flake's inputs.
  # perSystem.nullkomma.nix.unit.inputs = …;

  # [nix-unit](https://github.com/nix-community/nix-unit) tests, exported as
  # `tests.systems.<system>`; if any, they become the `nix-unit` check.
  # perSystem.nullkomma.nix.unit.tests = { };
}
```
<!-- nullkomma:nix:end -->

### `shell`

<!-- nullkomma:shell:start -->
```nix
{
  # Whether to enable the shell plugin.
  nullkomma.shell.enable = true;

  # Directory with the [bats](https://bats-core.readthedocs.io) tests, relative
  # to the project root. If it exists, they become the `bats` check.
  # nullkomma.shell.bats.testDir = "test";

  # [bats
  # libraries](https://bats-core.readthedocs.io/en/stable/writing-tests.html#bats-load-library-load-a-system-wide-library),
  # loadable with `bats_load_library`.
  # perSystem.nullkomma.shell.bats.libraries = [ ];

  # Packages on `PATH` while the bats tests run.
  # perSystem.nullkomma.shell.bats.packages = [ ];
}
```
<!-- nullkomma:shell:end -->

### `agents`

Writes an `agents` section into `AGENTS.md`, the rest of which is yours,
and generates the [MCP servers and skills](#mcp-servers-and-skills).
With `browser.enable`, which `quarto` and Shiny turn on,
agents operate the previews in [Playwright's](https://github.com/microsoft/playwright-mcp) headless browser.

<!-- nullkomma:agents:start -->
```nix
{
  # Whether to enable the agents plugin.
  nullkomma.agents.enable = true;

  # Whether to enable a headless browser for agents, to open and operate the
  # project's web previews, through Playwright's MCP server.
  # nullkomma.agents.browser.enable = false;

  # Agent Skill directories by name, each with a `SKILL.md` whose `name`
  # matches; plugins add here. The `agents` plugin generates them into
  # `.agents/skills/<name>`.
  # nullkomma.agents.skills = { };

  # MCP servers by name, each with a `type` (`stdio` with `command` and `args`,
  # or `http` with `url`); plugins add here. The `agents` plugin writes them to
  # `.mcp.json`, the `vscode` plugin to `.vscode/mcp.json`; stdio servers start
  # in the dev shell, when enabled.
  # perSystem.nullkomma.agents.mcpServers = { };
}
```
<!-- nullkomma:agents:end -->

### `github`

Writes `.github/workflows/push.yml`, which calls nullkomma's reusable CI workflow:
it runs `nix flake check` on each supported system,
then publishes pushes to the default branch and tags to FlakeHub, with the repository's visibility.
Forks don't publish; private flakes need a [FlakeHub paid plan](https://flakehub.com/signup).

<!-- nullkomma:github:start -->
```nix
{
  # Whether to enable the github plugin.
  nullkomma.github.enable = true;

  # Git ref of the reusable workflows; null for local workflows.
  # nullkomma.github.workflows.ref = "main";

  # Where the reusable workflows live (`./.github/workflows` for local ones).
  # nullkomma.github.workflows.source = "dataheld/nullkomma/.github/workflows";
}
```
<!-- nullkomma:github:end -->

### `gitlab`

In `nix/local.nix`:

<!-- nullkomma:gitlab:start -->
```nix
{
  # Whether to enable the gitlab plugin.
  nullkomma.gitlab.enable = true;

  # Cache check and site build dependencies in `.gitlab-nix-cache/`, per ref and
  # keyed by `flake.lock`. Restoring imports unsigned paths, so the job user
  # must be root or a trusted Nix user: keep GitLab's protected-branch cache
  # separation enabled. Transfers can cost more than they save on persistent
  # runners.
  # nullkomma.gitlab.cache.enable = false;

  # Image with Nix for Docker and Kubernetes executors. Shell executors ignore
  # it and use the runner's Nix.
  # nullkomma.gitlab.image = "nixos/nix:2.35.4";

  # Nix settings added to `NIX_CONFIG`. The defaults build in parallel
  # (`max-jobs = auto`) and fail instead of building unsandboxed when `sandbox =
  # true` is not possible (`sandbox-fallback = false`). The job log shows the
  # effective `max-jobs`, `cores` and `sandbox`. A Nix daemon ignores most
  # settings from users it does not trust.
  # nullkomma.gitlab.nixConfig = "";

  # Build `packages.x86_64-linux.site` after the checks in every pipeline, and
  # publish it to GitLab Pages on default-branch pushes. Requires a site
  # provider, such as `quarto` or R's pkgdown, and GitLab 17.10 or newer.
  # nullkomma.gitlab.pages.enable = false;

  # Tags that select the runners for all jobs.
  # nullkomma.gitlab.tags = [ ];
}
```
<!-- nullkomma:gitlab:end -->

### Editors

`vscode` and `neovim` render the plugins' language servers, formatter, MCP servers and recommended extensions
into generated `.vscode/*.json` and `.nvim.lua`.
Neovim reads `.nvim.lua` only with `:set exrc`; its `:Format` command formats through treefmt.
Installing editors belongs to your user environment, e.g. [lap](https://github.com/dataheld/lap).

### `quarto`

Renders the project into `packages.site`; `quarto-preview` serves it and reloads on edits.
Site resources are copied as files,
including those linked from outside the output directory.
For a documentation site, select nkdocs, a Quarto extension nullkomma generates, in `_quarto.yml`:

```yaml
project:
  type: nkdocs
website:
  title: My project
  repo-url: https://github.com/example/project
```

nkdocs only switches on stock Quarto features; configure everything else in `_quarto.yml` as usual.
With `brand.enable`, list the generated `_nullkomma-brand.yml` in `_quarto.yml`'s `metadata-files`.

<!-- nullkomma:quarto:start -->
```nix
{
  # Whether to enable the quarto plugin.
  nullkomma.quarto.enable = true;

  # Whether to enable the shared brand on the Quarto website.
  # nullkomma.quarto.brand.enable = false;

  # Quarto extensions by name, placed in `_extensions/<name>` (generated and
  # Git-ignored) and in the build.
  # nullkomma.quarto.extensions = { };

  # Generated page, relative to `root`, rendering `nullkomma.privacy.sections`
  # if there are any; null to write your own.
  # nullkomma.quarto.privacy.page = "privacy.qmd";

  # Quarto project rendered into `packages.site` and served by the
  # `quarto-preview` task.
  # nullkomma.quarto.root = self.outPath;

  # Quarto, without R, Python or TeX; override to add execution engines.
  # Default: `pkgs.quartoMinimal`, patched for Nixpkgs' Pandoc.
  # perSystem.nullkomma.quarto.package = …;
}
```
<!-- nullkomma:quarto:end -->

### `cloudflare`

Serves `packages.site` as [Workers static assets][cloudflare] at `https://<name>.<domain>`,
deployed with [Terranix], including DNS and the HTTPS certificate;
it leaves the parent domain and `workers.dev` alone.
`nk cloudflare-plan` previews changes and `nk cloudflare-deploy` publishes; CI runs `nix run .#deploy`.
Both need an existing private R2 bucket for Terraform state, and these variables, e.g. in GitHub Actions:

```yaml
env:
  CLOUDFLARE_ACCOUNT_ID: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
  CLOUDFLARE_STATE_BUCKET: ${{ vars.CLOUDFLARE_STATE_BUCKET }}
  # Account API token: Workers Scripts Edit
  CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  # R2 API token: Object Read & Write on the state bucket only
  CLOUDFLARE_R2_ACCESS_KEY_ID: ${{ secrets.CLOUDFLARE_R2_ACCESS_KEY_ID }}
  CLOUDFLARE_R2_SECRET_ACCESS_KEY: ${{ secrets.CLOUDFLARE_R2_SECRET_ACCESS_KEY }}
```

OpenTofu's S3 backend gets the R2 credentials as `AWS_*`; no AWS account is involved.

<!-- nullkomma:cloudflare:start -->
```nix
{
  # Whether to enable the cloudflare plugin.
  nullkomma.cloudflare.enable = true;

  # Existing Cloudflare zone serving `<name>.<domain>`; null disables the
  # shorthand.
  # nullkomma.cloudflare.domain = null;

  # Subdomain label and default Worker name; null infers the repository name
  # from `GITHUB_REPOSITORY` or Git origin at deployment time.
  # nullkomma.cloudflare.name = null;

  # Worker serving `packages.site`; also keys its Terraform state.
  # nullkomma.cloudflare.worker = config.nullkomma.cloudflare.name;
}
```
<!-- nullkomma:cloudflare:end -->

### `python`

Enable it for a pure-Python package at the flake root:
[uv2nix] and [pyproject.nix] build it from `pyproject.toml` and `uv.lock`, preferring dependency wheels.
Native extensions and `[tool.uv] conflicts` are not supported.

<!-- nullkomma:python:start -->
```nix
{
  # Whether to enable the python plugin.
  nullkomma.python.enable = true;

  # Nix Python interpreter; must satisfy the project's requires-python.
  # perSystem.nullkomma.python.interpreter = pkgs.python3;

  # pyproject.nix overlay for native libraries and package build fixes, applied
  # after uv.lock.
  # perSystem.nullkomma.python.overlay = final: prev: {};

  # Extra commands available to pytest, for example pkgs.git.
  # perSystem.nullkomma.python.test.packages = [ ];
}
```
<!-- nullkomma:python:end -->

### `r`

Enable it, then run `nix run .#r-lock`: the development shell needs the `pkg.lock` it writes.

Interactive R sessions started in the package directory load it with `pkgload::load_all()`,
after running `~/.Rprofile`, from a generated, Git-ignored `.Rprofile`.
If loading fails, R still starts.
To keep a committed `.Rprofile` of your own, set
`perSystem.nullkomma.files.".Rprofile".enable = false`.

<!-- nullkomma:r:start -->
```nix
{
  # Whether to enable the r plugin.
  nullkomma.r.enable = true;

  # Whether to allow R packages that nixpkgs does not provide: pinned `Remotes:`
  # (`owner/repo@commit`, `git::`, `url::`, `pkg@version`, `cran::pkg@version`)
  # and CRAN packages not (yet) in nixpkgs. They are built from the sources
  # pinned in the lockfile (commits, or `nullkomma.r.hashes`), against nixpkgs'
  # versions of their dependencies. Enabled by default, extending builds beyond
  # `nixpkgs-r`; set to `false` to require every R package to come from
  # `nixpkgs-r`.
  # nullkomma.r.allowOffNixpkgs = true;

  # Arguments to `R CMD check`. Set them without `--no-tests` to also run the
  # tests inside `R CMD check`. Default: `--no-manual --ignore-vignettes`, plus
  # `--as-cran` if `cranBound` and `--no-tests` while `r-test` runs the tests.
  # nullkomma.r.check.args = …;

  # Whether to add the `r-check` check (build and check the package with
  # rcmdcheck).
  # nullkomma.r.check.enable = true;

  # Least severe `R CMD check` finding that fails the check.
  # nullkomma.r.check.errorOn = "note";

  # Provide r-test-coverage, writing a local Cobertura coverage.xml report; no
  # uploads or coverage threshold. Default: whether covr is in pkg.lock.
  # nullkomma.r.coverage.enable = …;

  # Whether the package is meant for CRAN. If so, `r-check` runs `R CMD check
  # --as-cran`, without CRAN's incoming checks, which need network access. If
  # not, `r-check` skips what only CRAN needs: CRAN and Bioconductor index
  # lookups, for dependency cycles and for links to packages that are not
  # installed, and CRAN's limits on installed size and data compression.
  # nullkomma.r.cranBound = true;

  # Extra R packages from nixpkgs (e.g. dev tooling not in DESCRIPTION); pak,
  # languageserver, pkgload, httpgd, later and rstudioapi are always included.
  # nullkomma.r.extraPackages = [ ];

  # DESCRIPTION fields whose packages pak resolves. Override with only
  # `Depends`, `Imports` and `LinkingTo` for runtime-only dependencies. Default:
  # `Depends`, `Imports`, `LinkingTo`, `Suggests`, and all `Config/Needs/*`
  # fields in DESCRIPTION.
  # nullkomma.r.fields = …;

  # Hashes of R packages fetched by URL (`url::`, `pkg@version`, CRAN packages
  # missing from nixpkgs) when `nullkomma.r.allowOffNixpkgs` is set; pak's
  # lockfile has no hashes of these URLs. Get one with `nix store prefetch-file
  # <url>`.
  # nullkomma.r.hashes = { };

  # Lint and auto-fix R code with jarl. Configure its CLI switches through
  # perSystem.treefmt.settings.formatter.jarl.options; native config files are
  # unsupported.
  # nullkomma.r.jarl.enable = true;

  # Whether to enable R development without Nix using the same pinned
  # dependencies.
  # nullkomma.r.nonNix.enable = false;

  # Directory generated into pkgdown/assets and copied by pkgdown to the website
  # root in both local and sandboxed builds. Git-ignored; null keeps
  # project-owned assets.
  # nullkomma.r.pkgdown.assets = null;

  # Whether to enable the shared brand on the pkgdown website.
  # nullkomma.r.pkgdown.brand.enable = false;

  # Native pkgdown configuration merged over _pkgdown.yml in both local and
  # sandboxed builds, e.g. template.bslib.brand and footer.components for shared
  # branding.
  # nullkomma.r.pkgdown.config = { };

  # Build a pkgdown website with r-build-site (`--preview` opens it in a
  # browser) and packages.site, both built by `all`, and serve it with live
  # reload with r-preview-site.
  # nullkomma.r.pkgdown.enable = true;

  # Page at the site root rendering `nullkomma.privacy`, built by pkgdown
  # without writing to the project; null to supply your own.
  # nullkomma.r.pkgdown.privacy.page = "privacy.html";

  # Posit Package Manager (PPM) repository URL corresponding to
  # `nullkomma.r.snapshot`.
  # nullkomma.r.ppmUrl = "https://packagemanager.posit.co/cran/${snapshot}";

  # R package directory (containing `DESCRIPTION` and its pak lockfile
  # `pkg.lock`, written by `nix run .#r-lock`); a path literal inside the flake
  # if not its root.
  # nullkomma.r.root = self.outPath;

  # Exported functions whose apps `r-run-app` serves side by side, the n-th on
  # `port` + n, or a free one above it.
  # nullkomma.r.shiny.devFunctions = [ config.nullkomma.r.shiny.function ];

  # Whether to enable a runnable Shiny app as apps.shiny.
  # nullkomma.r.shiny.enable = false;

  # Exported function in the project package, called without arguments to obtain
  # a shiny.appobj.
  # nullkomma.r.shiny.function = "app";

  # Address on which the Shiny server listens; set 0.0.0.0 to expose it beyond
  # localhost.
  # nullkomma.r.shiny.host = "127.0.0.1";

  # Preferred port of the Shiny server; if taken, the next free one. null lets
  # Shiny choose an available port.
  # nullkomma.r.shiny.port = 3838;

  # CRAN snapshot date, for PPM and non-Nix interop. The default is the date in
  # the ref of `nixpkgs-r`, or else its commit date: an upper bound, as nixpkgs
  # updates its R packages less often. Set it for an exact date.
  # nullkomma.r.snapshot = date of nixpkgs-r;

  # Run testthat with `r-test`: on the pkgload-loaded source in the dev loop and
  # `check`, on the installed package in nix flake check (or with `nk r-test
  # --installed`).
  # nullkomma.r.testthat.enable = true;

  # Chrome-compatible browser for shinytest2/chromote. On macOS, null uses
  # chromote's locally installed Chrome discovery; sandboxed browser tests
  # require Linux or a supplied Nix browser. Default: Chromium with Liberation
  # and DejaVu fonts on Linux when chromote (e.g. via shinytest2) is in pkg.lock
  # or extraPackages; otherwise null.
  # perSystem.nullkomma.r.browser = …;

  # System libraries to add to the build of an R package, for packages whose
  # needs nixpkgs does not know (typically `Remotes:`).
  # perSystem.nullkomma.r.buildInputs = { };

  # R libraries pkgdown builds load packages from first, e.g. one holding a
  # pkgdown template package selected by `template.package`.
  # perSystem.nullkomma.r.pkgdown.libraries = [ ];
}
```
<!-- nullkomma:r:end -->

#### Dependencies

Declare dependencies in `DESCRIPTION`, including `Config/Needs/*` fields;
[pak] locks them in `pkg.lock`.
After changing them or updating Nix, run `nk r-lock` and commit both files.
Nix takes package names from `pkg.lock`, but versions and builds from the `nixpkgs-r` input;
`r-lock` resolves against the [PPM] snapshot of `nullkomma.r.snapshot`, by default an upper bound.
The development environment holds exactly these packages, the tools in the table above,
and `extraPackages`.

> [!NOTE]
> Packages from `Remotes`, or missing from `nixpkgs-r`, build from their lockfile-pinned sources
> unless `allowOffNixpkgs = false`.
> URL sources and CRAN packages missing from `nixpkgs-r` need `hashes.<package>`
> from `nix store prefetch-file <url>`. GitLab and local references are unsupported; use `git::` for GitLab.

#### pkgdown website

`packages.site` builds the [pkgdown] site in the sandbox, and `nk r-build-site` in the working tree;
`r-preview-site` serves it and reloads open pages when it is rebuilt.
pkgdown's online lookups, such as for CRAN/Bioconductor links, always find nothing;
add repository links with `home.links`.
Remote templates, web fonts and network-dependent articles must be local for the sandbox.

#### Shiny app

Export a function that returns a `shiny.appobj` when called without arguments,
e.g. `app <- function() shiny::shinyApp(ui, server)`, and declare `shiny` in `DESCRIPTION`.
`nix run .#shiny` installs the package and serves the app,
with only its `Depends`/`Imports` closure.
`process-compose up` serves each of `devFunctions` from the working tree with pkgload,
restarts them when `r-document-namespace` reruns or another file that R installs changes, such as in `inst/`,
and reloads open pages once a new app process serves them.
They run in [Shiny's developer mode](https://shiny.posit.co/r/reference/shiny/latest/devmode.html)
and record a [reactlog](https://rstudio.github.io/reactlog/).
With mcptools 1.0.1 or later, they register as sessions of the `r` MCP server.
Test the app with [shinytest2](https://rstudio.github.io/shinytest2/articles/use-package.html) by passing the exported function, `shinytest2::AppDriver$new(app)`:
with a pre-created app object or a wrapper defined in a test file, it runs the installed package instead of the working tree.
For an app with arguments, create a function in the package namespace, e.g. `rlang::new_function(NULL, quote(run_app(x = 1)), asNamespace("mypkg"))`.

`nk r-test` loads the working-tree source.
Flake checks and `nk r-test --installed` test a fresh installation,
including its installed namespace.

#### R development without Nix

For collaborators without Nix, enable `nullkomma.r.nonNix.enable`, run `nk write-files`,
and commit `.Renviron`, `.Rprofile`, `.R/install.R`, `.Rbuildignore`
and the section it adds to your README.
The startup profile installs from the same PPM snapshot in native R sessions only.

## Development

nullkomma uses itself; `nk` lists its own tasks.
[AGENTS.md](https://github.com/dataheld/nullkomma/blob/main/AGENTS.md)
holds the rules for changing it.
This README is also nullkomma's website, a branded nkdocs site,
deployed to Cloudflare after CI succeeds on `main`.

## Scope

nullkomma is **per-project** Nix scaffolding for devshells, formatters, checks, tasks, CI and editor settings, packaged as composable [flake-parts](https://flake.parts) modules.
It contributes to the infrastructure laid out in [aoshima](https://github.com/dataheld/aoshima), and follows [its charter](https://github.com/dataheld/aoshima#charter).
It is **not**:

| Concern                                                  | Lives in                                                |
| -------------------------------------------------------- | ------------------------------------------------------- |
| Fleet placement, clan, networking, fleet secrets         | [dataheld/aoshima](https://github.com/dataheld/aoshima) |
| Host baseline (boot, disk, hardening, host services)     | [dataheld/pads](https://github.com/dataheld/pads)       |
| User environment policy (home-manager, shell ergonomics) | [dataheld/lap](https://github.com/dataheld/lap)         |
| Agentic coding app / runtime                             | [dataheld/gittens](https://github.com/dataheld/gittens) |

[^deploy]: terranix also exports it as `packages.deploy`, whose `.init`, `.plan`, `.destroy`,
    `.terraform` and `.config` attributes `nix run` and `nix build` reach, e.g. `nix run .#deploy.plan`.

[air]: https://posit-dev.github.io/air/
[bash-language-server]: https://github.com/bash-lsp/bash-language-server
[bats]: https://bats-core.readthedocs.io
[brand.yml]: https://posit-dev.github.io/brand-yml/
[btw]: https://posit-dev.github.io/btw/
[cloudflare]: https://developers.cloudflare.com/workers/static-assets/
[direnv]: https://direnv.net
[flakehub]: https://flakehub.com
[git]: https://git-scm.com
[gitleaks]: https://github.com/gitleaks/gitleaks
[httpgd]: https://github.com/nx10/httpgd
[jarl]: https://jarl.etiennebacher.com
[jscpd]: https://github.com/kucherenko/jscpd
[json]: https://www.json.org
[jsonls]: https://github.com/hrsh7th/vscode-langservers-extracted
[keep-sorted]: https://github.com/google/keep-sorted
[languageserver]: https://github.com/REditorSupport/languageserver
[later]: https://later.r-lib.org
[mcp]: https://modelcontextprotocol.io
[mcptools]: https://posit-dev.github.io/mcptools/
[md]: https://commonmark.org
[nix-direnv]: https://github.com/nix-community/nix-direnv
[nixd]: https://github.com/nix-community/nixd
[opentofu]: https://opentofu.org
[pak]: https://pak.r-lib.org
[pkgdown]: https://pkgdown.r-lib.org
[ppm]: https://packagemanager.posit.co
[process-compose]: https://f1bonacc1.github.io/process-compose/
[process-compose-flake]: https://github.com/Platonic-Systems/process-compose-flake
[pyproject.nix]: https://pyproject-nix.github.io/pyproject.nix/
[python]: https://www.python.org
[r]: https://www.r-project.org
[radian]: https://github.com/randy3k/radian
[rstudioapi]: https://rstudio.github.io/rstudioapi/
[ruff]: https://docs.astral.sh/ruff/
[terranix]: https://terranix.org/flake-parts.html
[toml]: https://toml.io
[treefmt]: https://treefmt.com
[typos]: https://github.com/crate-ci/typos
[ty]: https://docs.astral.sh/ty/
[uv]: https://docs.astral.sh/uv/
[uv2nix]: https://pyproject-nix.github.io/uv2nix/
[yaml]: https://yaml.org
[yaml-language-server]: https://github.com/redhat-developer/yaml-language-server
[`actionlint`]: https://github.com/rhysd/actionlint
[`deadnix`]: https://github.com/astro/deadnix
[`fh`]: https://github.com/DeterminateSystems/fh
[`flake-checker`]: https://github.com/DeterminateSystems/flake-checker
[`jsonfmt`]: https://github.com/caarlos0/jsonfmt
[`mdformat`]: https://github.com/hukkin/mdformat
[`nixf-diagnose`]: https://github.com/inclyc/nixf-diagnose
[`nixfmt`]: https://github.com/NixOS/nixfmt
[`pkgload`]: https://pkgload.r-lib.org
[`quarto`]: https://quarto.org
[`rumdl`]: https://github.com/rvben/rumdl
[`shellcheck`]: https://www.shellcheck.net
[`shfmt`]: https://github.com/mvdan/sh
[`toml-sort`]: https://github.com/pappasam/toml-sort
[`wrangler`]: https://developers.cloudflare.com/workers/wrangler/
[`yamlfmt`]: https://github.com/google/yamlfmt
[`yamllint`]: https://github.com/adrienverge/yamllint
