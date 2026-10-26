# nullkomma ⚡️❄️

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/dataheld/nullkomma/badge)](https://flakehub.com/flake/dataheld/nullkomma)

Opinionated 🤓,
batteries-included 🔋,
extra-[DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) 🤌
[Nix](https://nixos.org) ❄️ boilerplate.

> nullkommanix [ɪn ˈnʊl ˌkɔma ˈnɪçt͡s] noun German colloquialism (translation: in next to time).

## Scope

nullkomma is **per-project** Nix scaffolding for devshells, formatters, checks, tasks, CI and editor settings, packaged as composable [flake-parts](https://flake.parts) modules.

It is **not**:

| Concern                                                  | Lives in                                                |
| -------------------------------------------------------- | ------------------------------------------------------- |
| Fleet placement, clan, networking, fleet secrets         | [dataheld/aoshima](https://github.com/dataheld/aoshima) |
| Host baseline (boot, disk, hardening, host services)     | [dataheld/pads](https://github.com/dataheld/pads)       |
| User environment policy (home-manager, shell ergonomics) | [dataheld/lap](https://github.com/dataheld/lap)         |
| Agentic coding app / runtime                             | [dataheld/gittens](https://github.com/dataheld/gittens) |

## Charter

This repo contributes to the broader IT infrastructure laid out in [aoshima](https://github.com/dataheld/aoshima).
When making changes, adhere to [aoshima's charter](https://github.com/dataheld/aoshima#charter).

## Getting started

### Prerequisites

1. Install Nix; the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer) is recommended.
   On Windows, use the [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install).
1. For automatic shell activation, install [direnv] and [nix-direnv] in your user environment,
   e.g. with [lap](https://github.com/dataheld/lap).
   Set [`hide_env_diff = true`](https://direnv.net/man/direnv.toml.1.html) to quiet it.

Everything else comes from your project's flake.

### Adding nullkomma to a project

In your project, run:

```sh
nix flake init --template "https://flakehub.com/f/dataheld/nullkomma/0.1.*#default"
git add flake.nix .envrc
nix develop --command nk-write-files
nix develop --command nk-generate-files
direnv allow
```

The template adds `flake.nix` and an `.envrc` with `use flake`, keeping existing files;
`nk-write-files` and `nk-generate-files` add the [files](#files-in-your-repository) that depend on your configuration.
From now on, entering the directory loads the [development shell](#devshells);
the first time takes a while.

The template's `nixpkgs.follows = "nullkomma/nixpkgs"` uses nullkomma's tested Nixpkgs.
To use your own, declare `nixpkgs.url` and set `nullkomma.inputs.nixpkgs.follows = "nixpkgs"`.

### Upgrading

Run `update`: it updates `flake.lock`, then runs `nk-write-files` and `nk-generate-files`.
After any other `nix flake update` (e.g. by a bot), run those two yourself.
After editing `flake.nix`, run `direnv reload`.

## Configuring

`nullkomma.lib.mkFlake` is flake-parts' `mkFlake` with every plugin imported and the default ones enabled,
so your `flake.nix` lists only exceptions and options.

For example:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  # All plugins and their settings: see "Plugins" below.
  nullkomma.quarto.enable = true; # opt in
  nullkomma.neovim.enable = false; # opt out
  perSystem =
    { pkgs, ... }:
    {
      nullkomma.devShell.packages = [ pkgs.hello ];
    };
}
```

### Plugins

Each plugin is one of nullkomma's `flakeModules.<name>`; each column is an output of your flake that it adds to.
All plugins are optional; those marked under Default are enabled unless you opt out.
Files and editor settings that plugins write into your repository are under [Plugin details](#plugin-details).

| Plugin                                              | Default | `devShells`                                                               | `formatter`[^treefmt]                | `checks`                                                | `packages`       | `apps`[^apps]              | `taskRunners`                                                                                                                                  | `processTrees`[^processTrees]                                                        |
| --------------------------------------------------- | ------- | ------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------- | ---------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| framework                                           | always  | every task, `tasks` runner                                                | [treefmt]                            | `treefmt`                                               | task `output`s   |                            | `check` (when checks exist), `format`, `nk-write-files`, `nk-generate-files`, [`watch-<task>`, `dev-<tree>`](#keeping-generated-files-current) | watched/process tasks and groups                                                     |
| [`nix`](#nix)                                       | ✅      | [nixd]                                                                    | `nixfmt`, `deadnix`, `nixf-diagnose` | [`nix-unit`](#tests)                                    |                  |                            | `update`, [`flake-checker`] [^flake-checker]                                                                                                   |                                                                                      |
| [`markdown`][md]                                    | ✅      | [marksman]                                                                | `mdformat`, `rumdl`                  |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`json`][json]                                      | ✅      | [JSON language server][jsonls]                                            | `jsonfmt`                            |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`yaml`][yaml]                                      | ✅      | [yaml-language-server]                                                    | `yamlfmt`, `yamllint`, `actionlint`  |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`toml`][toml]                                      | ✅      |                                                                           | `toml-sort`                          |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`shell`][bash]                                     | ✅      | [bash-language-server]                                                    | `shfmt`, `shellcheck`                | [bats] [^bats]                                          |                  |                            |                                                                                                                                                |                                                                                      |
| [`github`](#github)                                 | ✅      |                                                                           |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`keepSorted`][keep-sorted]                         | ✅      |                                                                           | `keep-sorted`                        |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`gitleaks`][gitleaks]                              | ✅      |                                                                           | `gitleaks`                           |                                                         |                  |                            | `secret-history`                                                                                                                               |                                                                                      |
| [`typos`][typos]                                    | ✅      |                                                                           | `typos`                              |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`jscpd`][jscpd]                                    | ✅      |                                                                           |                                      | `jscpd`                                                 |                  |                            |                                                                                                                                                |                                                                                      |
| [`git`](#git)                                       | ✅      | `git`                                                                     |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`direnv`](#direnv)                                 | ✅      |                                                                           |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`vscode`](#vscode-and-neovim)                      | ✅      |                                                                           |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`neovim`](#vscode-and-neovim)                      | ✅      |                                                                           |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`flakehub`][flakehub]                              | ✅      | [`fh`]                                                                    |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`quarto`](#quarto)                                 |         | `quarto`                                                                  |                                      |                                                         | `site`           |                            | `build-site`, `preview`, `dev-preview`                                                                                                         | `preview`                                                                            |
| [`quarto-website-brand`](#brand) (enables `quarto`) |         |                                                                           |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`cloudflare`](#cloudflare)                         |         | `wrangler`                                                                |                                      | `cloudflare` (OpenTofu validation)                      |                  | `deploy`[^deploy]          | `terraform`, `deploy`                                                                                                                          |                                                                                      |
| [`r`](#r)                                           |         | R, radian, Air; languageserver, `pkgload`, pak, httpgd, later, rstudioapi | `air`, `jarl`                        | `r-testthat`, `r-cmd-check`, `r-namespace`, `r-pkgdown` | `site` (pkgdown) | `r-lock`, `shiny` (opt-in) | `r-document`, `r-test`, `r-check`, `r-pkgdown`, `r-pkgdown-preview`, `r-coverage`, `r-lock`, `shiny` (opt-in); `dev-<tree>`                    | `r-document`, `r-test`, `r-check`, `r-pkgdown`, `r-pkg`; `shiny`, `r-shiny` (opt-in) |
| [`r-non-nix`](#r-non-nix) (enables `r`)             |         |                                                                           |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |
| [`r-brand`](#brand) (enables `r`)                   |         |                                                                           |                                      |                                                         |                  |                            |                                                                                                                                                |                                                                                      |

## Your flake outputs

These are your project's flake outputs; a `schemas` output describes them to [Determinate Nix](https://docs.determinate.systems)'s `nix flake show`.
Headings omit the system, which `perSystem` and commands like `nix build .#site` fill in: `site` is `packages.<system>.site`.

### `devShells`

#### `default`

The development shell holds:

- every task as a command, taking arguments (e.g. `nk-write-files --accept <path>`);
- the `tasks` runner;
- language servers and the formatter for [editors](#vscode-and-neovim);
- the plugins' and your `perSystem.nullkomma.devShell.packages`.

### `formatter`

`format` (or `nix fmt`) runs [treefmt] with every enabled plugin's formatters and linters;
`nix flake check` checks the same through [`checks.treefmt`](#treefmt).
Editors format with treefmt too (VS Code: [treefmt][vscode-treefmt]).

Generated files aren't formatted or linted: managed files and directories,
and R/pkgdown and Quarto build outputs.
Add other generated content to `nullkomma.generatedPaths` as treefmt globs, e.g. `[ "generated/**" ]`.

#### Customizing linting

**Configure linters in Nix, not in config files.** Native config files are ignored
(Jarl, which can't ignore them, fails instead); suppression comments such as `# shellcheck disable=SC2086` still work.
Your settings override plugins' `lib.mkDefault` values, and lists concatenate (`lib.mkForce` replaces one).

| Linter        | Nix configuration                                   | Settings to use                                                                                   |
| ------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| yamllint      | `perSystem.treefmt.programs.yamllint.settings`      | Attributes matching yamllint's YAML config                                                        |
| typos         | `nullkomma.lint.typos`                              | Attributes matching typos' TOML config                                                            |
| rumdl         | `nullkomma.lint.markdown`                           | Markdownlint rule IDs: `MD013 = false;` or rule settings                                          |
| actionlint    | `nullkomma.lint.actionlint`                         | Attributes matching actionlint's YAML config                                                      |
| gitleaks      | `nullkomma.lint.gitleaks`                           | Attributes matching its TOML config; upstream rules are retained by default                       |
| jscpd         | `nullkomma.lint.jscpd`                              | Attributes matching its JSON config; threshold defaults to zero, ignores extend shared exclusions |
| ShellCheck    | `perSystem.treefmt.programs.shellcheck`             | treefmt-nix options, e.g. `severity` and `extra-checks`                                           |
| deadnix       | `perSystem.treefmt.programs.deadnix`                | treefmt-nix switches, e.g. `no-lambda-arg`                                                        |
| nixf-diagnose | `perSystem.treefmt.programs.nixf-diagnose`          | treefmt-nix options, e.g. `ignore`                                                                |
| Jarl          | `perSystem.treefmt.settings.formatter.jarl.options` | CLI arguments, e.g. `[ "--ignore=any_is_na" ]`; file-only settings are not supported              |

For example, inside your `mkFlake` module:

```nix
nullkomma.lint = {
  typos.default.extend-words.foobaar = "foobaar";
  markdown.MD013 = false;
  jscpd.threshold = 5;
};

perSystem = { ... }: {
  treefmt.programs.yamllint.settings.rules.quoted-strings.required = true;
  treefmt.programs.deadnix.no-lambda-arg = true;
  treefmt.settings.formatter.typos.excludes = [ "snapshots/**" ];
  treefmt.settings.excludes = [ "vendor/**" ];
};
```

`treefmt.settings.excludes` skips files for every tool, jscpd included;
see [treefmt-nix's options](https://flake.parts/options/treefmt-nix.html) for more.
When migrating, move linter settings here and delete the old config files and `pyproject.toml` sections.

### `checks`

#### `treefmt`

Runs the [formatter](#formatter) and fails on formatting changes or lint errors.

#### `<name>`

Checks in `perSystem.nullkomma.checks.<name>`, e.g. test suites, run in your working tree with `check`,
and sandboxed against the flake's source in `nix flake check` and CI, with extra `sandboxArgs`.
Plugins add their own (see the `checks` column above); so can you:

```nix
perSystem = { pkgs, ... }: {
  nullkomma.checks.greeting = {
    packages = [ pkgs.hello ];
    command = "hello | grep -q Hello";
  };
};
```

### `tests`

With the `nix` plugin, the [nix-unit] tests in `perSystem.nullkomma.nix.unit.tests`,
exported as `tests.systems.<system>` (nix-unit's convention) and run by the `nix-unit` check.

### `packages`

#### `site`

[`quarto`](#quarto) or the [`r` plugin's pkgdown](#pkgdown-website) builds `packages.site`;
if both are enabled, set `perSystem.packages.site` yourself.

##### Brand

To theme sites from a brand flake exposing `lib.brand` (a brand.yml), declare its input and select it:

```nix
inputs.brand = {
  url = "github:example/brand";
  inputs.nullkomma.follows = "nullkomma";
};
# Inside mkFlake's module:
nullkomma.brand = inputs.brand;
```

Brand owns the declarations; nullkomma owns their translation and placement.
Without a brand, `quarto` and `r` keep Quarto's and pkgdown's defaults. One companion
plugin per site builder applies it, and enables its base plugin:

- `quarto-website-brand` generates `_nullkomma-brand.yml`; list it in `_quarto.yml`'s `metadata-files`.
- `r-brand` generates a pkgdown template package and selects it with `template.package`.

An optional `defaults.nullkomma.footer` record supplies footer facts to both builders:

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

Each `link` names an entry of `meta.link`; `privacy: true` links to your
[privacy policy](#privacy-policy), if there is one. `icon` is a
[Bootstrap Icon](https://icons.getbootstrap.com) name. Write plain text only:
Markdown or HTML fails the build.

##### Privacy policy

Plugins that process visitors' data add a section to `nullkomma.privacy.sections`
(`cloudflare` adds hosting and analytics); so can a brand or your project:

```nix
nullkomma.privacy.sections.booking = {
  order = 500; # cloudflare is 200
  markdown = {
    en = ./booking.en.md;
    de = ./booking.de.md;
  };
};
```

`quarto` renders them, by `order`, into `privacy.qmd` (`nullkomma.quarto.privacy.page`),
one tab per `nullkomma.privacy.languages`; pkgdown renders them to `/privacy.html`.
Link the page from your footer, or set it to `null` to write your own.
The sections are a starting point, not legal advice.

Technology-specific disclosures belong to the plugin using that technology, not the
brand; the framework's `nullkomma.privacy.policy` is also usable without either site builder.
For example, [`cloudflare`](#cloudflare) adds its own sections on Cloudflare hosting and analytics.

### `apps`

#### `deploy`

With [`cloudflare`](#cloudflare), publishes `packages.site`.

#### `r-lock`

With the `r` plugin, writes the [`pkg.lock`](#dependencies) the development shell needs.

#### `shiny`

With `nullkomma.r.shiny.enable = true`, serves the project's [Shiny app](#shiny-app)
at `http://127.0.0.1:3838` using the pinned R environment.

### `taskRunners`

#### `default`

[up]'s runner for the tasks in `perSystem.nullkomma.tasks.<name>`, where you can add your own:

```sh
tasks          # list tasks
tasks check    # run one task
tasks all      # run all tasks not marked skip
```

Tasks can change files: R checks regenerate documentation and `NAMESPACE`.
Set `skip = true` on custom tasks that should not run as part of `tasks all`.
The pinned [up] runner does not forward optional arguments; invoke the listed
task as a shell command for those, e.g. `preview --port 4200` or `check r-cmd-check`.

#### Workflows: one command and graph

`nullkomma.tasks` is the workflow definition, not a second build recipe.
Language plugins declare their defaults next to their implementation:
R documentation, tests and pkgdown in `modules/lang/r/workflow.nix`,
R CMD check in `modules/lang/r/checks.nix`, Shiny in `modules/lang/r/shiny.nix`,
and Quarto in `modules/lang/quarto/quarto.nix`.
Enabling the plugin supplies those tasks and processes; `tasks` lists them.

A task's `after` lists tasks whose steps run first, transitively and once each,
wherever it runs: as a command, through `tasks`, in builds, in `watch-<task>` and in process trees.
For example, `r-pkgdown`, `r-test`, `r-check`, `r-coverage` and `shiny` run after `r-document` (roxygen2),
so each always sees a current `NAMESPACE` and `man/`, through the same command you'd run by hand.
Outside process trees, steps run one after another and stop at the first failure.

```nix
perSystem.nullkomma.tasks.report = {
  description = "Render the report";
  after = [ "r-document" ];
  working_dir = ""; # checkout root, or the same root in the sandbox
  packages = [ pkgs.quarto ];
  command = ''
    quarto render report.qmd --output-dir "''${NULLKOMMA_OUTPUT:-report}"
  '';
  output = "report"; # adds packages.report; omit for development-only tasks
  watch.paths = [ "report.qmd" ]; # adds watch-report and dev-report
};
```

This adds `report`, `tasks report`, `watch-report`, `dev-report` and `nix build .#report`
from one definition. Builds run the same executable and DAG on a writable `nullkomma.src`,
with `NULLKOMMA_ROOT` pointing to that copy and `NULLKOMMA_OUTPUT` to the Nix output.
`working_dir` is relative to that root; if omitted, tasks keep the caller's directory.
`sandboxArgs` explicitly selects any necessary build-only behavior: R tests use
`--installed` in the sandbox, versus pkgload locally. There is no separate build command.

Extend defaults using ordinary flake-parts merging: add a task, append `after` prerequisites,
or use `lib.mkBefore`/`lib.mkAfter` for extra command lines and `lib.mkForce` to replace a command.
Builds, checks and processes then use the changed task too.
`before` is also supported. Up schedules the runner; nullkomma expands transitive prerequisites
because the pinned runner otherwise runs only direct prerequisites for a named task.

#### Keeping generated files current

These watches refresh artifacts derived from the working tree, such as roxygen2's
`NAMESPACE` and manuals. Files generated from Nix (editor settings, brand assets and
Quarto extensions) are separate: the dev shell refreshes them on entry with
`nk-generate-files`, and sandboxed builds use `nullkomma.src`.
Tasks and process trees don't regenerate those files.

`watch.paths` lists a task's project-relative inputs; paths not in the flake's source are skipped.
`watch-<task>` runs the task with its `after` steps whenever any of their inputs change
([watchexec], which skips Git-ignored files), until you stop it.

Every watched task automatically supplies a process tree containing its dependency graph.
For services with their own reloading, set `process = { };` without adding an outer watch:
Quarto's `dev-preview` uses Quarto's own watcher.
`process` also accepts native [up] process settings such as `readiness_probe` and `shutdown`;
the workflow owns `command` and merges its dependency edges into `depends_on`.

Additional groups, `perSystem.nullkomma.processTrees.<tree>`, keep several tasks current
in the background, as [process-compose] processes; `dev-<tree>` (also `nix run .#processTrees.<system>.<tree>`)
starts them with a dashboard showing which currently fail:

```nix
perSystem.nullkomma.processTrees.docs = {
  description = "Keep the report current";
  tasks = [ "report" ]; # plus its `after` tasks
};
```

- Tasks run in `after` order, independent ones in parallel.
- Each runs again when its `watch.paths` change, or when a task it runs after succeeds again.
- A failing task doesn't stop the tree. Only successful reruns notify dependents,
  so running dependents keep their last good state until it's fixed.
- Steps that write files (e.g. roxygen2) run once per tree, for every process that needs them;
  state of a single R session (e.g. pkgload in `shiny`) stays in that process.
- Successes are recorded as Git-ignored stamps in `.nullkomma/processes/<tree>/`,
  next to the tree's process-compose socket, so each worktree runs its own trees.

Trees don't start with the dev shell ([#217](https://github.com/dataheld/nullkomma/issues/217));
run `dev-<tree>` in a spare terminal.

## Files in your repository

nullkomma keeps files in your repository to a minimum; features live in Nix.
Some tools still need real files (Git needs `.gitignore`, GitHub needs workflows,
editors need settings). Each is one of two kinds:

|                             | **Source of truth** (committed, yours to edit) | **Generated from Nix** (Git-ignored, don't edit)           |
| --------------------------- | ---------------------------------------------- | ---------------------------------------------------------- |
| `nix flake init --template` | `flake.nix`, `.envrc`                          | (not possible)                                             |
| `nk-write-files`            | `.gitignore`, GitHub workflows                 |                                                            |
| `nk-generate-files`         |                                                | `.vscode/*.json`, `.nvim.lua`, Quarto brand and extensions |

Templates can't take parameters, so anything that depends on your configuration
comes from `nk-write-files` or `nk-generate-files`.

### Source-of-truth files

`nk-write-files` writes these once (`nullkomma.files."<path>".mode = "source"`, the default);
then they are yours to edit and commit.
When nullkomma later changes a file, `nk-write-files` updates it only if you haven't edited it.
Otherwise it keeps your version, saves an incoming copy in Git's metadata directory and fails,
printing the copy's path and pointing you to the [resolve-file-conflicts skill](#resolving-conflicts).
After resolving, `nk-write-files --accept <path>` marks the file as up to date.

A file can instead hold marked `sections` inside your own text (e.g. R's `.Rbuildignore` rules):
`nk-write-files` replaces only those, wherever you moved them.
Once nullkomma no longer declares a file (say, you disabled its plugin),
`nk-write-files` strips its sections, deletes it if unedited, or keeps your edited version and says so.

### Generated files

`nk-generate-files` overwrites these (`mode = "generated"`) when they differ from Nix,
starts them with a "do not edit" comment, and the `git` plugin ignores them.
They follow your Nix configuration, not your working tree:
entering the dev shell runs `nk-generate-files` if they changed, while tasks such as `preview` never do.
direnv re-enters when `flake.nix` or `flake.lock` change (say, after `update`);
if local Nix modules declare files too, add e.g. `watch_dir nix` to your `.envrc`.
To change one, change the Nix options.
Directories (`directory = true`) are copied whole, without the comment.
`nk-generate-files` refuses to overwrite a file tracked by Git,
and removes files it generated before that are no longer declared.

### Resolving conflicts

The repository root is a portable [Agent Plugins 1.0 package](https://agent-plugin.org/en)
with the [resolve-file-conflicts skill](https://github.com/dataheld/nullkomma/blob/main/.github/skills/resolve-file-conflicts/SKILL.md).
In Copilot, install it with `/plugin install https://github.com/dataheld/nullkomma`
and update it with `/plugin update nullkomma`; neither writes to your project.

## Plugin details

What plugins write into your repository ([source-of-truth or generated](#files-in-your-repository))
and how to configure them, where the table doesn't say it all.
Linter settings are under [Customizing linting](#customizing-linting).

### `nix`

Ignores `result` in `.gitignore`.
Unit tests for your flake's Nix code go in `perSystem.nullkomma.nix.unit.tests`;
see [`tests`](#tests).

### `github`

Writes `.github/workflows/push.yml`, a stub calling nullkomma's reusable CI workflow,
which runs `nix flake check` on each supported system.
After successful checks, pushes to the default branch and tags publish to FlakeHub:
Flake visibility always matches the repository: public repositories publish public, listed flakes;
private repositories publish private flakes. There is no visibility override.
Forks do not publish. Private flakes require a [FlakeHub paid plan](https://flakehub.com/signup).
Remove any existing `nullkomma.github.ci.inputs` settings and `with.visibility` workflow arguments.
`nullkomma.github.ci.secrets` passes repository secrets.

### `git`

Writes `.gitignore` from the top-level `nullkomma.gitignore` lines that plugins and you add,
plus every generated file.

### `direnv`

Writes `.envrc` (`use flake`), which loads the development shell on entering the directory,
and ignores `.direnv/`.

### `vscode` and `neovim`

Plugins declare language servers once, editor-neutrally (`perSystem.nullkomma.editor`).
The `vscode` and `neovim` plugins render them, with recommended extensions,
into generated, Git-ignored `.vscode/settings.json`, `.vscode/extensions.json` and `.nvim.lua`,
so nobody commits editor config.
Neovim reads `.nvim.lua` only with `:set exrc`.
Its `:Format` command formats the current buffer through treefmt.

Installing editors and extensions, themes and keybindings belong to your user environment,
e.g. [lap](https://github.com/dataheld/lap), which sets up the same two editors.

### `quarto`

Opt-in `quarto` renders the project into `packages.site`; `preview` serves it locally and reloads on edits.
It ignores `.quarto/`, `_site/` and Quarto's generated `.luarc.json`.
Shared Quarto extensions, e.g. from a brand flake, go in `nullkomma.quarto.extensions.<name>`,
generated into `_extensions/<name>`.
The [privacy policy](#privacy-policy) is generated into `privacy.qmd`.

For a documentation site, enable `nullkomma.quarto.enable = true` and select
nkdocs, a Quarto extension nullkomma generates, as the project type in your `_quarto.yml`:

```yaml
project:
  type: nkdocs
website:
  title: My project
  repo-url: https://github.com/example/project
```

nkdocs only switches on stock Quarto features and knows nothing of brands;
configure everything else in `_quarto.yml` as usual,
e.g. add pages to `website.sidebar.contents`. Set `repo-url` for repository actions.

[`quarto-website-brand`](#brand) styles Quarto websites, nkdocs or plain `website`, through generated
`_nullkomma-brand.yml`: branded light/dark themes, navbar, footer and privacy link,
on the standard Quarto theme rather than a separate Bootswatch theme.

All generated paths are relative to `nullkomma.quarto.root`, including nested docs
directories; they are the same files `packages.site` builds with.
The build task renders the working tree into Quarto's local output directory.

### `cloudflare`

Opt-in `cloudflare` serves whatever `packages.site` holds as [Workers static assets][cloudflare],
deployed with [Terranix], including custom domains, `_headers` and `_redirects`; `workers.dev` is disabled.
It adds hosting and analytics to the [privacy policy](#privacy-policy) and ignores `.nullkomma/cloudflare/`.

```nix
nullkomma.cloudflare = {
  enable = true;
  domain = "example.com";
  # name = "other-name"; # Override the repository-derived subdomain and Worker name.
  # worker = "existing-worker"; # Override only the Worker and Terraform state identity.
};
```

For a repository named `foo`, this publishes `https://foo.example.com`, including
DNS and HTTPS certificates managed by Cloudflare. `domain` is the name of an
existing active Cloudflare zone in your account.

Without `name`, deployment uses the repository name from `GITHUB_REPOSITORY`
(GitHub Actions), or the local Git `origin` remote (HTTPS or SSH, without `.git`).

The plugin only deploys to subdomains. It leaves the parent domain (for example,
`example.com`) and redirects alone. To serve `www.example.com`, set
`domain = "example.com"` and `name = "www"`.

Cloudflare creates the subdomain's DNS record and HTTPS certificate as part of
deployment; no Zone ID or separate DNS setup is needed.

If Cloudflare reports an existing CNAME DNS record at an address you want to use,
remove that record only if it no longer serves another site, then deploy again.

The old `domains` option is no longer accepted because it also allowed deploying
to the parent domain. Existing users must review their Terraform state migration
before switching to `domain` and `name`; do not simply remove the old setting and
apply, as the custom-domain resource address has changed.

Terraform state remains keyed as `<worker>.tfstate` in the shared R2 bucket.
Existing explicit Worker names and state keys are unchanged. Pin `name` before
renaming a repository to keep its inferred hostname and Worker/state identity;
pin `worker` separately if it differs. Worker names must be unique within the
account, and state keys within the bucket, including across repositories with
the same name. Changing these settings does not automatically migrate state.

Locally, run `terraform` to plan changes (or `terraform <command> [args]`) and `deploy` to publish;
in CI, run `nix run .#deploy`.
Both need an existing private R2 bucket for Terraform state; in GitHub Actions:

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

The plugin maps the R2 credentials internally to the `AWS_*` environment names
required by OpenTofu's S3-compatible backend; no AWS account is involved.
Use the same Cloudflare environment names for local deployment.

One-time setup for this repository:

1. Allow this repo access to the existing `CLOUDFLARE_API_TOKEN` and both `CLOUDFLARE_R2_*` organization secrets.
1. Set `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_STATE_BUCKET` Actions variables to the existing account and private state bucket.
1. Ensure the existing API token has **Account / Workers Scripts / Edit**; Custom Domains need no separate DNS token. Keep the R2 token scoped to **Object Read & Write** on the state bucket.

The parent zone must already be active in that account. This repo deploys assets
and DNS only after successful CI on pushes to `main`, never from PRs or tags.

### `r`

1. Add `nullkomma.r.enable = true;` to `flake.nix`; for a package in a subdirectory, also `nullkomma.r.root = ./pkg;`.
1. Run `nix run .#r-lock`: the development shell needs the [`pkg.lock`](#dependencies) it writes.
1. Run `nk-write-files` and commit the changes; run `nk-generate-files` for editor configuration.

#### Dependencies

Declare dependencies in `DESCRIPTION`; [pak] locks them in `pkg.lock`.
Refresh the lock after changing dependencies or updating Nix:

```sh
r-lock
git add DESCRIPTION pkg.lock
```

Nix takes package names from `pkg.lock`, but versions and builds from the `nixpkgs-r` input
(which follows Nixpkgs; override `inputs.nullkomma.inputs.nixpkgs-r` for newer R).
`r-lock` resolves against the [PPM] snapshot of the same date (`nullkomma.r.snapshot`);
it writes the lockfile, not an installed library, and requires Nix.
Outside Nix, [`r-non-nix`](#r-non-nix) installs from that PPM snapshot.

`Depends`, `Imports`, `LinkingTo`, `Suggests` and all `Config/Needs/*` fields are locked,
e.g. `Config/Needs/development: devtools`; override `nullkomma.r.fields` for a runtime-only lockfile.
The development environment holds exactly these, plus pkgload, pak, languageserver, httpgd, later, rstudioapi and the tools of enabled workflows;
`nullkomma.r.extraPackages` adds more.
So a package with three dependencies gets those three, one with Shiny gets Shiny,
and system libraries come with the packages that need them.

> [!NOTE]
> Packages from `Remotes`, or missing from `nixpkgs-r`, need `nullkomma.r.allowOffNixpkgs = true`.
> Git sources use the locked commit;
> URL sources also need `nullkomma.r.hashes.<package>` from `nix store prefetch-file <url>`.
> Add missing system libraries with `perSystem.nullkomma.r.buildInputs.<package>`.
> GitLab and local references are unsupported; use `git::` for GitLab.

#### Workflows

`tasks` describes the available workflows and lists the checks.
Disable optional checks and site builds with `nullkomma.r.{check,testthat,pkgdown}.enable`.
Checks, tests and site builds always regenerate roxygen2 documentation first.
`dev-r-pkg` keeps documentation, tests, the pkgdown site and `R CMD check` current while you work,
and `dev-r-shiny` (with the [Shiny app](#shiny-app)) also serves the app, reloading it in the browser
whenever documentation is regenerated (see [Keeping generated files current](#keeping-generated-files-current)).
Generated `man/*.Rd` files are Git-ignored, but not `man/` itself; commit `NAMESPACE`.
`nullkomma.r.check.errorOn` sets the failing severity (default `"note"`).
The `r` plugin keeps its package-build exclusions in a marked section of `.Rbuildignore`,
and ignores R build outputs in `.gitignore`.

`check r-testthat` is quick: it loads the source with pkgload instead of installing it.
`nix flake check` and CI run `check r-testthat --installed`, which tests an installed copy, as `R CMD check` does.
`Config/testthat/parallel: true` in `DESCRIPTION` runs tests [in parallel](https://testthat.r-lib.org/articles/parallel.html).

Locking chromote (e.g. via [shinytest2](https://rstudio.github.io/shinytest2/)) adds Chromium on Linux
(`perSystem.nullkomma.r.browser`); on macOS, which Nixpkgs' Chromium doesn't support, chromote finds your Chrome.

#### pkgdown website

`packages.site` builds the [pkgdown](https://pkgdown.r-lib.org) site in the sandbox,
also in `nix flake check`; `r-pkgdown` builds it locally, and `r-pkgdown-preview` also opens it.
[Cloudflare](#cloudflare) can publish it.

- A patch skips pkgdown's online CRAN/Bioconductor lookup; add those links with `home.links`.
- Bootstrap 5's JavaScript dependencies are pinned in nullkomma.
  Other remote templates, web fonts and network-dependent articles must be local for the sandbox.
- `_pkgdown.yml` overrides template packages, e.g. [`r-brand`](#brand)'s, which `nullkomma.r.pkgdown.libraries` provides;
  `nullkomma.r.pkgdown.config` is merged over both.
- `nullkomma.r.pkgdown.assets` is a directory generated into Git-ignored `pkgdown/assets/`,
  which pkgdown copies to the site root; leave it `null` to manage that directory yourself.
- The [privacy policy](#privacy-policy) is published at `/privacy.html`;
  set `nullkomma.r.pkgdown.privacy.page = null` to write your own.

#### Shiny app

Export a zero-argument function returning a `shiny.appobj`, e.g. `app <- function() shiny::shinyApp(ui, server)`,
declare `shiny` in `DESCRIPTION`, refresh `pkg.lock` and enable the launcher:

```nix
nullkomma.r.shiny = {
  enable = true;
  function = "app"; # default
  host = "0.0.0.0"; # default "127.0.0.1"; port defaults to 3838
};
```

`nix run .#shiny` installs your package from the flake's source, calls the function and serves the app.
The `shiny` task instead loads the working-tree package with pkgload, without installing it.
Its runtime is R, Shiny and your package's `Depends`/`Imports` closure: no `Suggests`, `Config/Needs/*`, `extraPackages` or pkgload.
Ship assets in `inst/` (find them with `system.file()`) and write data outside the installed package.

Test it by passing the function to
[shinytest2](https://rstudio.github.io/shinytest2/articles/use-package.html#application-objects):
`shinytest2::AppDriver$new(app)`.
Under `check r-testthat`, the app process loads your source with pkgload,
so there's nothing to install and no stale installed copy; with `--installed`, it uses the installed package.

#### Formatting and tools

[Air] formats R and [Jarl] lints and fixes it first, configured through [Nix](#customizing-linting)
(disable with `nullkomma.r.jarl.enable = false`).
R projects allow HTML and long lines in Markdown (`MD033`, `MD013`),
keep typos from "correcting" the author role `fnd` in `DESCRIPTION`,
and skip testthat snapshots and `docs/`.

The tools follow current r-lib practice:
[rcmdcheck](https://github.com/r-lib/actions/blob/v2/examples/check-standard.yaml),
[roxygen2](https://github.com/r-lib/actions/blob/v2/examples/document.yaml),
[pkgdown](https://github.com/r-lib/actions/blob/v2/examples/pkgdown.yaml)
and [covr](https://github.com/r-lib/actions/blob/v2/examples/test-coverage.yaml).
Jarl replaces lintr: it needs no package load and fixes lints before Air formats.
Coverage stays local, without an upload service.
Everything runs on one locked R version; add a CI matrix if you need Windows or other R releases.

### `r-non-nix`

For collaborators without Nix, enable `nullkomma.r-non-nix.enable = true` (it enables `r`),
run `nk-write-files`, and commit `.Renviron`, `.Rprofile`, `.R/install.R`, `.Rbuildignore`
and the [R development without Nix](https://github.com/dataheld/nullkomma/blob/main/modules/lang/r-non-nix/_assets/development.md) section added to your README.
These are [source-of-truth files](#source-of-truth-files).
The startup profile only acts in native R sessions, installing from the same PPM snapshot
(`nullkomma.r.snapshot`, `nullkomma.r.ppmUrl`); it leaves Nix shells, builds and tasks alone.

## Design

Nullkomma always provides **two self-documenting entrypoints**:

1. The consumer's flake outputs. These are already self-documenting.
1. `tasks` expose a selection of useful builds and checks.
   This does not mean that `tasks` aliases every subcommand and flag.
   As a heuristic, if some command is run to produce a flake output,
   it is also exposed as a `tasks`.
   In addition, `tasks` include important development-only workflows,
   especially previews.

R and Quarto artifact builds use the task's command and dependency graph,
not independently maintained copies. Intentional execution-context differences are:

- Tasks run tools directly on the working tree, rather than recursively invoking Nix builds for speed and simplicity.
- Tasks run on the *uncommitted* working tree for faster turnaround.
- Sandboxed builds and checks use `nullkomma.src`, a writable copy of the flake's source with Nix-generated files.
- R tests use pkgload locally and install the package in the sandbox; Shiny's published app also uses an installed package without development dependencies.

The non-Nix R compatibility layer necessarily documents its own bootstrap.

The [Plugins](#plugins) table maps nullkomma's outputs onto yours:
each row is one of nullkomma's `flakeModules.<name>`, each column an output of your flake.
Every output is fed by framework options (in `perSystem`) that plugins fill in, and so can you:

| Your output                   | Options                   | Task                       |
| ----------------------------- | ------------------------- | -------------------------- |
| `devShells.default`           | `nullkomma.devShell.*`    |                            |
| `formatter`, `checks.treefmt` | `treefmt.programs`        | `format`                   |
| `checks.<name>`               | `nullkomma.checks.<name>` | `check`                    |
| `packages.site`               | `packages.site`           | `build-site` / `r-pkgdown` |
| `apps.<name>`                 | `apps.<name>`             | plugin-specific            |
| `taskRunners`                 | `nullkomma.tasks.<name>`  | `tasks`                    |

Formatting and linting are treefmt's job: plugins add `treefmt.programs`, not their own runner.
Two more framework options act on your working tree rather than on outputs:
`nullkomma.files.<path>` (and the top-level `nullkomma.gitignore`), written by `nk-write-files` and `nk-generate-files`;
and `nullkomma.editor`, whose language servers join the dev shell and which `vscode` and `neovim` render into files.

Independent plugins do not read each other's options. Values shared between plugins are
framework options that any plugin may set or read. For example, `r` relaxes Markdown
rules through `nullkomma.lint.markdown`, which `markdown` hands to rumdl; neither
knows about the other.

A companion plugin may import and enable its base plugin and reuse its options:
`r-non-nix` and `r-brand` depend on `r`, and `quarto-website-brand` on `quarto`, but no base
plugin depends on its companions.

Because plugins only meet through framework options, one could live in its own flake,
e.g. a `nullkomma-r` exporting `flakeModules.r` against `flakeModules.framework`,
keeping R-only inputs out of other projects' lockfiles.

## Development

Before building something, check [flake.parts](https://flake.parts) for an
existing module; see [AGENTS.md](https://github.com/dataheld/nullkomma/blob/main/AGENTS.md). Inputs only nullkomma's own
development needs go in [`dev/flake.nix`](https://github.com/dataheld/nullkomma/blob/main/dev/flake.nix), so they stay out of
projects' `flake.lock`.

### Documentation website

nullkomma's own website is this README, built as a [`quarto`](#quarto) nkdocs
site into [`packages.site`](#site) styled by [`quarto-website-brand`](#brand) with [Max Held's](https://www.maxheld.de) brand and
[privacy policy](#privacy-policy). `tasks` lists how to preview and check it.

### Testing nullkomma

nullkomma is tested against small example projects ("fixtures") in
`tests/fixtures`, which use nullkomma the way a real project would.

- **Unit tests** ([nix-unit]) check the fixtures' evaluated configuration, e.g. that every plugin can be switched off.
  They fetch dev-only inputs through the `nix` plugin's network-enabled fixed-output derivation.
- **Docs test:** `options-doc` renders every option as [flake.parts](https://flake.parts) would, so each needs a description.
- **Legal tests:** `site-legal` and `r-pkgdown-legal` build this site and a pkgdown fixture with the real brand, and check that every page links an imprint and the privacy policy, which covers GDPR Art. 13 in English and German and every footer email address.
- **Build tests** run the real tools on the fixtures in `nix flake check`; Nix and Markdown files listed in `rejects` must fail.
- **End-to-end test:** `check-fixtures` runs `nix flake check` on a copy of a fixture against this checkout, as a user would,
  the only test of how real projects fetch nullkomma. CI runs it on every push.
- **Without Nix:** `test-r-non-nix` builds the `r-non-nix` fixture in Docker (Ubuntu 24.04, `linux/amd64`, no Nix),
  runs the documented R examples and builds the package; extra arguments go to `docker build`. CI runs it on manual dispatch.

New plugins should add a valid and a deliberately broken fixture, and check that
the broken one fails with the real tool's error, not just any error.

`pkgdown-dependencies` refreshes the pinned pkgdown Bootstrap 5 dependencies.

[^treefmt]: `nix fmt` and the `format` task fix what they can; `checks.<system>.treefmt`
    fails `nix flake check` (and CI) on any remaining formatting or lint issue.

[^apps]: `packages` are what Nix builds (`nix build`), `apps` what it runs (`nix run`):
    a program, e.g. a deploy script or a Shiny server, usually backed by a package.

[^processTrees]: [up] process trees, each also the `dev-<tree>` task; see
    [Keeping generated files current](#keeping-generated-files-current).

[^flake-checker]: The `flake-checker` task checks `flake.lock` for outdated or non-upstream Nixpkgs inputs.

[^bats]: Tests in `test/` (`nullkomma.shell.bats.testDir`), once that directory
    exists; add the tools they call with `perSystem.nullkomma.shell.bats.packages`.
    `*.bats` files are formatted and linted like other shell scripts.

[^deploy]: terranix also exports it as `packages.deploy`, whose `.init`, `.plan`, `.destroy`,
    `.terraform` and `.config` attributes `nix run` and `nix build` reach, e.g. `nix run .#deploy.plan`.

[air]: https://posit-dev.github.io/air/
[bash]: https://www.gnu.org/software/bash/
[bash-language-server]: https://github.com/bash-lsp/bash-language-server
[bats]: https://bats-core.readthedocs.io
[cloudflare]: https://developers.cloudflare.com/workers/static-assets/
[direnv]: https://direnv.net
[flakehub]: https://flakehub.com
[gitleaks]: https://github.com/gitleaks/gitleaks
[jarl]: https://jarl.etiennebacher.com
[jscpd]: https://github.com/kucherenko/jscpd
[json]: https://www.json.org
[jsonls]: https://github.com/hrsh7th/vscode-langservers-extracted
[keep-sorted]: https://github.com/google/keep-sorted
[marksman]: https://github.com/artempyanykh/marksman
[md]: https://commonmark.org
[nix-direnv]: https://github.com/nix-community/nix-direnv
[nix-unit]: https://github.com/nix-community/nix-unit
[nixd]: https://github.com/nix-community/nixd
[pak]: https://pak.r-lib.org
[ppm]: https://packagemanager.posit.co
[process-compose]: https://f1bonacc1.github.io/process-compose/
[terranix]: https://terranix.org/flake-parts.html
[toml]: https://toml.io
[treefmt]: https://treefmt.com
[typos]: https://github.com/crate-ci/typos
[up]: https://github.com/DeterminateSystems/up
[vscode-treefmt]: https://marketplace.visualstudio.com/items?itemName=ibecker.treefmt-vscode
[watchexec]: https://watchexec.github.io
[yaml]: https://yaml.org
[yaml-language-server]: https://github.com/redhat-developer/yaml-language-server
[`fh`]: https://github.com/DeterminateSystems/fh
[`flake-checker`]: https://github.com/DeterminateSystems/flake-checker
