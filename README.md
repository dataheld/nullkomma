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
nix develop --command write-files
nix develop --command generate-files
direnv allow
```

The template adds `flake.nix` and an `.envrc` with `use flake`, keeping existing files;
`write-files` and `generate-files` add the [files](#files-in-your-repository) that depend on your configuration.
From now on, entering the directory loads the [development shell](#devshells);
the first time takes a while.

The template's `nixpkgs.follows = "nullkomma/nixpkgs"` uses nullkomma's tested Nixpkgs.
To use your own, declare `nixpkgs.url` and set `nullkomma.inputs.nixpkgs.follows = "nixpkgs"`.

### Upgrading

Run `update`: it updates `flake.lock`, then runs `write-files` and `generate-files`.
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
  nullkomma.github.ci.inputs.visibility = "public"; # publish to FlakeHub
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

| Plugin                                  | Default | `devShells`                              | `formatter`[^treefmt]                | `checks`                                                | `packages`       | `apps`[^apps]              | `taskRunners`                                                          |
| --------------------------------------- | ------- | ---------------------------------------- | ------------------------------------ | ------------------------------------------------------- | ---------------- | -------------------------- | ---------------------------------------------------------------------- |
| framework                               | always  | every task, `tasks` runner               | [treefmt]                            | `treefmt`                                               |                  |                            | `check` (when checks exist), `format`, `write-files`, `generate-files` |
| [`nix`](#nix)                           | ✅      | [nixd]                                   | `nixfmt`, `deadnix`, `nixf-diagnose` | [`nix-unit`](#tests)                                    |                  |                            | `update`, [`flake-checker`] [^flake-checker]                           |
| [`markdown`][md]                        | ✅      | [marksman]                               | `mdformat`, `rumdl`                  |                                                         |                  |                            |                                                                        |
| [`json`][json]                          | ✅      | [JSON language server][jsonls]           | `jsonfmt`                            |                                                         |                  |                            |                                                                        |
| [`yaml`][yaml]                          | ✅      | [yaml-language-server]                   | `yamlfmt`, `yamllint`, `actionlint`  |                                                         |                  |                            |                                                                        |
| [`toml`][toml]                          | ✅      |                                          | `toml-sort`                          |                                                         |                  |                            |                                                                        |
| [`shell`][bash]                         | ✅      | [bash-language-server]                   | `shfmt`, `shellcheck`                | [bats] [^bats]                                          |                  |                            |                                                                        |
| [`github`](#github)                     | ✅      |                                          |                                      |                                                         |                  |                            |                                                                        |
| [`keepSorted`][keep-sorted]             | ✅      |                                          | `keep-sorted`                        |                                                         |                  |                            |                                                                        |
| [`gitleaks`][gitleaks]                  | ✅      |                                          | `gitleaks`                           |                                                         |                  |                            | `secret-history`                                                       |
| [`typos`][typos]                        | ✅      |                                          | `typos`                              |                                                         |                  |                            |                                                                        |
| [`jscpd`][jscpd]                        | ✅      |                                          |                                      | `jscpd`                                                 |                  |                            |                                                                        |
| [`git`](#git)                           | ✅      | `git`                                    |                                      |                                                         |                  |                            |                                                                        |
| [`direnv`](#direnv)                     | ✅      |                                          |                                      |                                                         |                  |                            |                                                                        |
| [`vscode`](#vscode-and-neovim)          | ✅      |                                          |                                      |                                                         |                  |                            |                                                                        |
| [`neovim`](#vscode-and-neovim)          | ✅      |                                          |                                      |                                                         |                  |                            |                                                                        |
| [`flakehub`][flakehub]                  | ✅      | [`fh`]                                   |                                      |                                                         |                  |                            |                                                                        |
| [`quarto`](#quarto)                     |         | `quarto`, configured execution engines   |                                      |                                                         | `site`           |                            | `preview`                                                              |
| [`cloudflare`](#cloudflare)             |         | `wrangler`                               |                                      | `cloudflare` (OpenTofu validation)                      |                  | `deploy`[^deploy]          | `terraform`, `deploy`                                                  |
| [`r`](#r)                               |         | R with languageserver, `pkgload` and pak | `air`, `jarl`                        | `r-testthat`, `r-cmd-check`, `r-namespace`, `r-pkgdown` | `site` (pkgdown) | `r-lock`, `shiny` (opt-in) | `r-document`, `r-pkgdown`, `r-coverage`, `r-lock`                      |
| [`r-non-nix`](#r-non-nix) (enables `r`) |         |                                          |                                      |                                                         |                  |                            |                                                                        |

## Your flake outputs

These are your project's flake outputs; a `schemas` output describes them to [Determinate Nix](https://docs.determinate.systems)'s `nix flake show`.
Headings omit the system, which `perSystem` and commands like `nix build .#site` fill in: `site` is `packages.<system>.site`.

### `devShells`

#### `default`

Use: direnv, `nix develop`.

The development shell holds:

- every task as a command, taking arguments (e.g. `write-files --accept <path>`);
- the `tasks` runner;
- language servers and the formatter for [editors](#vscode-and-neovim);
- the plugins' and your `perSystem.nullkomma.devShell.packages`.

### `formatter`

Use: `format`, `nix fmt`, `nix flake check`.

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

Use: `nix flake check`.

Runs the [formatter](#formatter) and fails on formatting changes or lint errors.

#### `<name>`

Use: `check [<name>] [args]`, `nix flake check`.

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

Use: `check nix-unit`.

With the `nix` plugin, the [nix-unit] tests in `perSystem.nullkomma.nix.unit.tests`,
exported as `tests.systems.<system>` (nix-unit's convention) and run by the `nix-unit` check.

### `packages`

#### `site`

Use: `nix build .#site`.

[`quarto`](#quarto) or the [`r` plugin's pkgdown](#pkgdown-website) builds `packages.site`;
if both are enabled, set `perSystem.packages.site` yourself.

##### Brand

To theme sites from a brand flake, declare its input and select it:

```nix
inputs.brand = {
  url = "https://flakehub.com/f/dataheld/brand/0.1.*";
  inputs.nullkomma.follows = "nullkomma";
};
# Inside mkFlake's module:
nullkomma.brand = inputs.brand;
```

The brand provides `lib.brand` (a [brand.yml](https://posit-dev.github.io/brand-yml/) file),
optionally `lib.footer` (HTML) and `flakeModules.privacy`.
Its privacy sections join every site's privacy policy.
Quarto uses its native brand installer to generate `_brand/` with the theme and its assets;
pkgdown applies the theme and footer.

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

### `apps`

#### `deploy`

Use: `nix run .#deploy`.

With [`cloudflare`](#cloudflare), publishes `packages.site`.

#### `r-lock`

Use: `nix run .#r-lock`.

With the `r` plugin, writes the [`pkg.lock`](#dependencies) the development shell needs.

#### `shiny`

Use: `nix run .#shiny`.

With `nullkomma.r.shiny.enable = true`, serves the project's [Shiny app](#shiny-app)
at `http://127.0.0.1:3838` using the pinned R environment.

### `taskRunners`

#### `default`

Use: `tasks`.

[up]'s runner for the tasks in `perSystem.nullkomma.tasks.<name>`, where you can add your own:

```sh
tasks          # list tasks
tasks check    # run one task
tasks all      # run all tasks not marked skip
```

Tasks can change files: R checks regenerate documentation and `NAMESPACE`.
Set `skip = true` on custom tasks that should not run as part of `tasks all`.

## Files in your repository

nullkomma keeps files in your repository to a minimum; features live in Nix.
Some tools still need real files (Git needs `.gitignore`, GitHub needs workflows,
editors need settings). Each is one of two kinds:

|                             | **Source of truth** (committed, yours to edit) | **Generated from Nix** (Git-ignored, don't edit)           |
| --------------------------- | ---------------------------------------------- | ---------------------------------------------------------- |
| `nix flake init --template` | `flake.nix`, `.envrc`                          | (not possible)                                             |
| `write-files`               | `.gitignore`, GitHub workflows                 |                                                            |
| `generate-files`            |                                                | `.vscode/*.json`, `.nvim.lua`, Quarto brand and extensions |

Templates can't take parameters, so anything that depends on your configuration
comes from `write-files` or `generate-files`.

### Source-of-truth files

`write-files` writes these once (`nullkomma.files."<path>".mode = "source"`, the default);
then they are yours to edit and commit.
When nullkomma later changes a file, `write-files` updates it only if you haven't edited it.
Otherwise it keeps your version, saves an incoming copy in Git's metadata directory and fails,
printing the copy's path and pointing you to the [resolve-file-conflicts skill](#resolving-conflicts).
After resolving, `write-files --accept <path>` marks the file as up to date.

A file can instead hold marked `sections` inside your own text (e.g. R's `.Rbuildignore` rules):
`write-files` replaces only those, wherever you moved them.
Once nullkomma no longer declares a file (say, you disabled its plugin),
`write-files` strips its sections, deletes it if unedited, or keeps your edited version and says so.

### Generated files

`generate-files` overwrites these (`mode = "generated"`) on every run,
starts them with a "do not edit" comment, and the `git` plugin ignores them.
To change one, change the Nix options.
Directories (`directory = true`) are copied whole, without the comment.
`generate-files` refuses to overwrite a file tracked by Git,
and removes files it generated before that are no longer declared.

### Resolving conflicts

The repository root is a portable [Agent Plugins 1.0 package](https://agent-plugin.org/en)
with the [resolve-file-conflicts skill](.github/skills/resolve-file-conflicts/SKILL.md).
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
`nullkomma.github.ci.inputs.visibility = "public"` also publishes to FlakeHub;
`nullkomma.github.ci.secrets` passes repository secrets.

For a Cloudflare site, opt into deployment after the shared CI succeeds:

```nix
nullkomma.github.ci = {
  inputs = {
    deploy = true;
    cloudflare-account-id = "<account ID>";
    cloudflare-state-bucket = "<existing private R2 bucket>";
  };
  secrets = [
    "CLOUDFLARE_API_TOKEN"
    "CLOUDFLARE_R2_ACCESS_KEY_ID"
    "CLOUDFLARE_R2_SECRET_ACCESS_KEY"
  ];
};
```

Deployment runs `nix run .#deploy` only on non-fork default-branch pushes after
all checks and builds pass. Pull requests never run it. Production applies are
serialized and are not cancelled by newer pushes; the generated caller also
keeps default-branch runs alive. The token and R2 credentials use the permissions
described under [Cloudflare](#cloudflare).

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
It ignores `.quarto/` and `_site/`.
Shared Quarto extensions, e.g. from a brand flake, go in `nullkomma.quarto.extensions.<name>`,
generated into `_extensions/<name>`; a selected [brand](#brand) themes rendering and preview.
The [privacy policy](#privacy-policy) is generated into `privacy.qmd`.

Preview refreshes generated files before starting. Rendering, preview and the
development shell share `perSystem.nullkomma.quarto.runtimeInputs`, so execution
engines and PDF tools need not be installed separately:

```nix
nullkomma.quarto.renderArgs = [ "-M" "latex-clean:false" ];
perSystem = { config, pkgs, ... }: {
  nullkomma.quarto = {
    runtimeInputs = [
      config.nullkomma.r.package
      pkgs.texliveSmall
    ];
    postRender = ''
      if grep -q 'WARN' render.log; then
        echo "Quarto emitted a warning" >&2
        exit 1
      fi
    '';
  };
};
```

This example assumes the `r` plugin is enabled and its package dependencies include
`rmarkdown`. Customize TeX with Nixpkgs' `texliveSmall.withPackages`. TeX is an
optional rendering dependency, not a separate editor/linter stack.
`renderArgs` applies to sandboxed rendering; `postRender` runs in the Quarto root
with the captured `render.log` and the rendered site at `$out`. Both render failures
and failed post-render checks fail the build.

### `cloudflare`

Opt-in `cloudflare` serves whatever `packages.site` holds as [Workers static assets][cloudflare],
deployed with [Terranix], including custom domains, `_headers` and `_redirects`; `workers.dev` is disabled.
It adds hosting and analytics to the [privacy policy](#privacy-policy) and ignores `.nullkomma/cloudflare/`.

```nix
nullkomma.cloudflare = {
  enable = true;
  worker = "my-site";
  domains."www.example.org" = "<zone ID>";
};
```

Locally, run `terraform` to plan changes (or `terraform <command> [args]`) and `deploy` to publish;
in CI, run `nix run .#deploy`.
Both need an existing private R2 bucket for Terraform state; in GitHub Actions:

```yaml
env:
  CLOUDFLARE_ACCOUNT_ID: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
  CLOUDFLARE_STATE_BUCKET: ${{ vars.CLOUDFLARE_STATE_BUCKET }}
  # Account API token: Workers Scripts Edit
  CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN_WORKERS }}
  # R2 API token: Object Read & Write on the state bucket only
  AWS_ACCESS_KEY_ID: ${{ secrets.CLOUDFLARE_R2_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.CLOUDFLARE_R2_SECRET_ACCESS_KEY }}
```

### `r`

1. Add `nullkomma.r.enable = true;` to `flake.nix`; for a package in a subdirectory, also `nullkomma.r.root = ./pkg;`.
1. Run `nix run .#r-lock`: the development shell needs the [`pkg.lock`](#dependencies) it writes.
1. Run `write-files` and commit the changes.

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
The development environment holds exactly these, plus pkgload, pak, languageserver and the tools of enabled workflows;
`nullkomma.r.extraPackages` adds more.
So a package with three dependencies gets those three, one with Shiny gets Shiny,
and system libraries come with the packages that need them.

> [!NOTE]
> Packages from `Remotes`, or missing from `nixpkgs-r`, need `nullkomma.r.allowOffNixpkgs = true`.
> Git sources use the locked commit;
> URL sources also need `nullkomma.r.hashes.<package>` from `nix store prefetch-file <url>`.
> Add missing system libraries with `perSystem.nullkomma.r.buildInputs.<package>`.
> GitLab and local references are unsupported; use `git::` for GitLab.

#### Tasks and checks

| Command             | What it does                                                                                                      | Opt out                                                           |
| ------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `r-document`        | Generate `man/*.Rd` and `NAMESPACE` with roxygen2                                                                 | `nullkomma.r.document.enable` (for hand-written manuals)          |
| `check r-cmd-check` | Build and run rcmdcheck                                                                                           | `nullkomma.r.check.enable`                                        |
| `check r-testthat`  | Run testthat on the source, loaded with pkgload; `--installed` tests an installed copy, as `nix flake check` does | `nullkomma.r.testthat.enable`                                     |
| `check r-namespace` | Fail if roxygen2 would change the committed `NAMESPACE`                                                           | with `r-document`                                                 |
| `r-pkgdown`         | Build the [website](#pkgdown-website) into `docs/`                                                                | `nullkomma.r.pkgdown.enable`                                      |
| `r-coverage`        | Write a local Cobertura `coverage.xml` with covr                                                                  | off unless covr is locked or `nullkomma.r.coverage.enable = true` |

Checks, tests and site builds regenerate documentation first.
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
also in `nix flake check`; `r-pkgdown` builds it locally.
[Cloudflare](#cloudflare) can publish it.

- A patch skips pkgdown's online CRAN/Bioconductor lookup; add those links with `home.links`.
- Bootstrap 5's JavaScript dependencies are pinned in nullkomma.
  Other remote templates, web fonts and network-dependent articles must be local for the sandbox.
- `nullkomma.r.pkgdown.config` is merged over `_pkgdown.yml`, overriding the [brand](#brand).
- `nullkomma.r.pkgdown.assets` is a directory generated into Git-ignored `pkgdown/assets/`,
  which pkgdown copies to the site root; leave it `null` to manage that directory yourself.
- The [privacy policy](#privacy-policy) is generated into Git-ignored `.github/privacy.md`, which pkgdown renders to `/privacy.html`;
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
run `write-files`, and commit `.Renviron`, `.Rprofile`, `.R/install.R`, `.Rbuildignore`
and the [R development without Nix](modules/lang/r-non-nix/_assets/development.md) section added to your README.
These are [source-of-truth files](#source-of-truth-files).
The startup profile only acts in native R sessions, installing from the same PPM snapshot
(`nullkomma.r.snapshot`, `nullkomma.r.ppmUrl`); it leaves Nix shells, builds and tasks alone.

## Design

The [Plugins](#plugins) table maps nullkomma's outputs onto yours:
each row is one of nullkomma's `flakeModules.<name>`, each column an output of your flake.
Every output is fed by framework options (in `perSystem`) that plugins fill in, and so can you:

| Your output                   | Options                   | Task     |
| ----------------------------- | ------------------------- | -------- |
| `devShells.default`           | `nullkomma.devShell.*`    |          |
| `formatter`, `checks.treefmt` | `treefmt.programs`        | `format` |
| `checks.<name>`               | `nullkomma.checks.<name>` | `check`  |
| `packages.<name>`             | `packages.<name>`         |          |
| `apps.<name>`                 | `apps.<name>`             |          |
| `taskRunners`                 | `nullkomma.tasks.<name>`  | `tasks`  |

Formatting and linting are treefmt's job: plugins add `treefmt.programs`, not their own runner.
Two more framework options act on your working tree rather than on outputs:
`nullkomma.files.<path>` (and the top-level `nullkomma.gitignore`), written by `write-files` and `generate-files`;
and `nullkomma.editor`, whose language servers join the dev shell and which `vscode` and `neovim` render into files.

Independent plugins do not read each other's options. Values shared between plugins are
framework options that any plugin may set or read. For example, `r` relaxes Markdown
rules through `nullkomma.lint.markdown`, which `markdown` hands to rumdl; neither
knows about the other.

A companion plugin may import and enable its base plugin and reuse its options:
`r-non-nix` depends on `r`, but `r` does not depend on the compatibility layer.

Because plugins only meet through framework options, one could live in its own flake,
e.g. a `nullkomma-r` exporting `flakeModules.r` against `flakeModules.framework`,
keeping R-only inputs out of other projects' lockfiles.

## Development

Before building something, check [flake.parts](https://flake.parts) for an
existing module; see [AGENTS.md](AGENTS.md). Inputs only nullkomma's own
development needs go in [`dev/flake.nix`](dev/flake.nix), so they stay out of
projects' `flake.lock`.

### Testing nullkomma

nullkomma is tested against small example projects ("fixtures") in
`tests/fixtures`, which use nullkomma the way a real project would.

- **Unit tests** ([nix-unit]) check the fixtures' evaluated configuration, e.g. that every plugin can be switched off.
  They fetch dev-only inputs through the `nix` plugin's network-enabled fixed-output derivation.
- **Docs test:** `options-doc` renders every option as [flake.parts](https://flake.parts) would, so each needs a description.
- **Build tests** run the real tools on the fixtures in `nix flake check`; Nix and Markdown files listed in `rejects` must fail.
- **End-to-end test:** `check-fixtures` runs `nix flake check` on a copy of a fixture against this checkout, as a user would,
  the only test of how real projects fetch nullkomma. CI runs it on every push.
- **Without Nix:** `test-r-non-nix` builds the `r-non-nix` fixture in Docker (Ubuntu 24.04, `linux/amd64`, no Nix),
  runs the documented R examples and builds the package; extra arguments go to `docker build`. CI runs it on manual dispatch.

```sh
nix flake check   # unit, docs and build tests
check-fixtures    # end-to-end test
test-r-non-nix    # R without Nix, in Docker
```

New plugins should add a valid and a deliberately broken fixture, and check that
the broken one fails with the real tool's error, not just any error.

`pkgdown-dependencies` refreshes the pinned pkgdown Bootstrap 5 dependencies.

[^treefmt]: `nix fmt` and the `format` task fix what they can; `checks.<system>.treefmt`
    fails `nix flake check` (and CI) on any remaining formatting or lint issue.

[^apps]: `packages` are what Nix builds (`nix build`), `apps` what it runs (`nix run`):
    a program, e.g. a deploy script or a Shiny server, usually backed by a package.

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
[terranix]: https://terranix.org/flake-parts.html
[toml]: https://toml.io
[treefmt]: https://treefmt.com
[typos]: https://github.com/crate-ci/typos
[up]: https://github.com/DeterminateSystems/up
[vscode-treefmt]: https://marketplace.visualstudio.com/items?itemName=ibecker.treefmt-vscode
[yaml]: https://yaml.org
[yaml-language-server]: https://github.com/redhat-developer/yaml-language-server
[`fh`]: https://github.com/DeterminateSystems/fh
[`flake-checker`]: https://github.com/DeterminateSystems/flake-checker
