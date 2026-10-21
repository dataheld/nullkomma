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
From now on, entering the directory loads the [development shell](#development-shell);
the first time takes a while.

The template's `nixpkgs.follows = "nullkomma/nixpkgs"` uses nullkomma's tested Nixpkgs.
To use your own, declare `nixpkgs.url` and set `nullkomma.inputs.nixpkgs.follows = "nixpkgs"`.

### Upgrading

Run `update`: it updates `flake.lock`, then runs `write-files` and `generate-files`.
After any other `nix flake update` (e.g. by a bot), run those two yourself.
After editing `flake.nix`, run `direnv reload`.

## Configuring

`nullkomma.lib.mkFlake` is flake-parts' `mkFlake` with every plugin imported and the default ones enabled,
so `flake.nix` lists only exceptions and options:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.quarto.enable = true; # opt in
  nullkomma.github.enable = false; # opt out
  nullkomma.github.ci.inputs.visibility = "public"; # publish to FlakeHub
  perSystem =
    { pkgs, ... }:
    {
      nullkomma.devHelpers = [ pkgs.hello ];
    };
}
```

### Plugins

Everything nullkomma adds comes from a plugin.
All are optional; the ones not marked opt-in are enabled by default.

| Plugin                              | Dev helpers    | Format / lint          | Tests                                                    | Files                                                              | Editor                                                           |
| ----------------------------------- | -------------- | ---------------------- | -------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------- |
| [`nix`][nix]                        |                | ✅, [`flake-checker`]¹ | [nix-unit]²                                              | ignores `result`                                                   | [nixd]; VS Code: [Nix IDE]                                       |
| [`markdown`][md]                    |                | ✅                     |                                                          |                                                                    | [marksman]                                                       |
| [`json`][json]                      |                | ✅                     |                                                          |                                                                    | [JSON language server][jsonls]                                   |
| [`yaml`][yaml]                      |                | ✅                     |                                                          |                                                                    | [yaml-language-server]; VS Code: [YAML][vscode-yaml]             |
| [`toml`][toml]                      |                | ✅                     |                                                          |                                                                    |                                                                  |
| [`shell`][bash]                     |                | ✅³                    | [bats]³                                                  |                                                                    | [bash-language-server]; VS Code: [Bash IDE], [Bats][vscode-bats] |
| [`github`][gha]                     |                |                        |                                                          | `push.yml`⁴                                                        |                                                                  |
| [`keepSorted`][keep-sorted]         |                | ✅                     |                                                          |                                                                    |                                                                  |
| [`gitleaks`][gitleaks]              | secret-history | ✅ secrets             |                                                          |                                                                    |                                                                  |
| [`typos`][typos]                    |                | ✅ spelling⁷           |                                                          |                                                                    |                                                                  |
| [`jscpd`][jscpd]                    |                |                        | duplicated code                                          |                                                                    |                                                                  |
| [`treefmt`][treefmt]                |                | runs all ✅            |                                                          |                                                                    | formatter; VS Code: [treefmt][vscode-treefmt]                    |
| [`git`][git]                        | git            |                        |                                                          | `.gitignore`                                                       |                                                                  |
| [`direnv`][direnv]                  |                |                        |                                                          | `.envrc`, ignores `.direnv/`                                       | VS Code: [Nix Environment Selector]                              |
| [`vscode`][vscode]                  |                |                        |                                                          | `.vscode/`⁵                                                        | renders it for VS Code⁵                                          |
| [`neovim`][neovim]                  |                |                        |                                                          | `.nvim.lua`⁵                                                       | renders it for Neovim⁵                                           |
| [`flakehub`][flakehub]              | [`fh`]         |                        |                                                          |                                                                    |                                                                  |
| [`quarto`][quarto] (opt-in)         | quarto⁹        |                        |                                                          | ignores `.quarto/`, `_site/`; `_extensions/`⁸, `privacy.qmd`⁸      | VS Code: [Quarto][vscode-quarto]                                 |
| [`cloudflare`][cloudflare] (opt-in) | wrangler⁶      |                        | OpenTofu validation                                      | ignores `.nullkomma/cloudflare/`                                   |                                                                  |
| [`r`][r] (opt-in)                   | R, pak         | ✅                     | strict rcmdcheck, testthat, pkgdown, namespace freshness | `.Rbuildignore`, R ignores, `.github/privacy.md`⁸, pkgdown assets⁸ | R languageserver; VS Code: R, Air                                |
| `r-non-nix` (opt-in, enables `r`)   |                |                        |                                                          | `.Rprofile`, `.Renviron`, `.R/install.R`, README                   |                                                                  |

¹ The `flake-checker` task lints `flake.lock` for outdated or non-upstream
Nixpkgs. The `nix` plugin also adds the tasks `check` (`nix flake check`) and
`update` (`nix flake update`, then refresh files).

² Tests in `perSystem.nullkomma.nix.unit.tests`, once there are any; exported as
`tests.systems.<system>`.

³ Tests in `test/` (`nullkomma.shell.bats.testDir`), once that directory
exists; add the tools they call with `perSystem.nullkomma.shell.bats.packages`.
`*.bats` files are formatted and linted like other shell scripts.

⁴ `.github/workflows/push.yml`, a stub calling nullkomma's reusable CI workflow,
which runs `nix flake check` and can publish to FlakeHub.

⁵ Generated (Git-ignored) from the Editor column: VS Code settings and
recommended extensions in `.vscode/`, language servers in `.nvim.lua`.

⁶ Also adds the `terraform` (plan changes) and `deploy` tasks, and a section
to the privacy policy (see [Websites](#websites)).

⁷ Skips translations such as `*.de.md`, one pattern per non-English
`nullkomma.privacy.languages`; typos only knows English.

⁸ Generated: `nullkomma.quarto.extensions`, `nullkomma.r.pkgdown.assets`, and
the privacy policy once there are `nullkomma.privacy.sections`.

⁹ Also adds the `preview` task: `quarto preview`, serving the site on localhost
and re-rendering and live-reloading it on changes.

✅ means the plugin's files are formatted/linted by the `format` task (or `nix fmt`) and
checked by `nix flake check` (via treefmt). The exact tools are in the plugin's source.

## Outputs

Your flake gets these outputs:

| Output                                 | Use                                    | See                                               |
| -------------------------------------- | -------------------------------------- | ------------------------------------------------- |
| `devShells.default`                    | direnv, `nix develop`                  | [Development shell](#development-shell)           |
| `formatter`, `checks.<system>.treefmt` | `format`, `nix fmt`, `nix flake check` | [Formatting and linting](#formatting-and-linting) |
| `checks.<system>.test-<name>`          | `test <name>`, `nix flake check`       | [Tests](#tests)                                   |
| `tests.systems.<system>`               | [nix-unit]                             | [Tests](#tests)                                   |
| `packages.site`, `packages.deploy`     | `nix build .#site`, `nix run .#deploy` | [Websites](#websites)                             |
| `packages.r-lock`                      | `nix run .#r-lock`                     | [R](#r)                                           |
| `taskRunners.<system>`                 | `tasks`                                | [Development shell](#development-shell)           |

A `schemas` output describes them to [Determinate Nix](https://docs.determinate.systems)'s `nix flake show`.

### Development shell

`devShells.default` holds:

- every task as a command, taking arguments (e.g. `write-files --accept <path>`);
- the `tasks` runner from [up] to list and run them;
- language servers and the formatter for [editors](#editors);
- the plugins' and your `nullkomma.devHelpers`.

```sh
tasks          # list tasks
tasks check    # run one task
tasks all      # run all tasks that don't change files
```

Tools a task or test needs stay inside it, off your `PATH`.
Add your own tasks in `perSystem.nullkomma.tasks.<name>`.

#### Editors

Plugins declare language servers once, editor-neutrally (`perSystem.nullkomma.editor`).
The `vscode` and `neovim` plugins render them, with recommended extensions,
into Git-ignored `.vscode/` and `.nvim.lua`, so nobody commits editor config.
Neovim reads `.nvim.lua` only with `:set exrc`.

Installing editors and extensions, themes and keybindings belong to your user environment,
e.g. [lap](https://github.com/dataheld/lap), which sets up the same two editors.

### Formatting and linting

`format` (or `nix fmt`) runs [treefmt] with every enabled plugin's formatters and linters;
`nix flake check` checks the same as `checks.<system>.treefmt`.

Generated files aren't formatted or linted: managed files and directories,
and R/pkgdown and Quarto build outputs.
Add other generated content to `nullkomma.generatedPaths` as treefmt globs, e.g. `[ "generated/**" ]`.

#### Customizing linting

Commit each tool's native configuration; nullkomma never writes these files.
It hands its shared policy to each tool through the tool's own layering, without merging configurations itself.

| Tool         | Native configuration                                                               | How it combines with shared policy                                                                                                                                 |
| ------------ | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| typos        | `.typos.toml`, `typos.toml`, `_typos.toml`, or `[tool.typos]` in `pyproject.toml`  | Shared settings are passed with `--config`: native files add words, file types and `files.extend-exclude`; shared settings win conflicting keys.                   |
| markdownlint | `.markdownlint-cli2.{jsonc,yaml,cjs,mjs}` or `.markdownlint.{jsonc,json,yaml,yml}` | Shared rules are the `--config` base: `config` in `.markdownlint-cli2.*` overrides them by rule name, a `.markdownlint.*` file replaces them. `globs` are ignored. |
| yamllint     | `.yamllint`, `.yamllint.yaml`, `.yamllint.yml`                                     | Shared defaults are yamllint's user-global config, so a project file replaces them.                                                                                |
| Jarl         | `jarl.toml`                                                                        | Native only: nullkomma passes no shared Jarl settings.                                                                                                             |
| ShellCheck   | `.shellcheckrc` and source directives                                              | Native only.                                                                                                                                                       |
| actionlint   | `.github/actionlint.yaml` or `.github/actionlint.yml`                              | Native only.                                                                                                                                                       |
| jscpd        | `.jscpd.json`, `.config/jscpd.json`, or the `jscpd` key in `package.json`          | Project `ignore` globs add to the shared exclusions; other settings win, e.g. `threshold` (a percentage, default 0) or `"formatsExts": { "nix": ["nix"] }`.        |
| gitleaks     | `.gitleaks.toml`, `.gitleaksignore`                                                | Native only; include `[extend]` with `useDefault = true` to retain upstream detection rules.                                                                       |

For example, add spellings and skip a vendor directory in `.typos.toml`:

```toml
[default.extend-words]
foobaar = "foobaar"

[files]
extend-exclude = ["vendor/**"]
```

Disable a Markdown rule and keep the shared ones in `.markdownlint-cli2.yaml`:

```yaml
config:
  MD042: false
```

A `.yamllint` starts from scratch; restate the shared defaults to keep them:

```yaml
extends: relaxed
rules:
  line-length: disable
  quoted-strings: {required: true}
```

To change shared policy in Nix, set `nullkomma.lint.typos`, `nullkomma.lint.markdown`
or `nullkomma.lint.yaml`; they merge through the module system. Without Nix,
linters see only native files.

Tools without native config files (e.g. deadnix) and extra arguments or exclusions
use [treefmt-nix](https://github.com/numtide/treefmt-nix) options:

```nix
perSystem = { ... }: {
  treefmt.programs.deadnix.no-lambda-arg = true;
  treefmt.settings.formatter.typos.excludes = [ "snapshots/**" ];
  treefmt.settings.excludes = [ "vendor/**" ];
};
```

A committed `treefmt.toml` is ignored.
Replacing a tool's `package` or typos' `configFile` drops the shared policy; typos' `isolated` ignores native files.
Linter ignores affect that linter only; treefmt exclusions skip formatters too.

### Tests

Test suites in `perSystem.nullkomma.tests.<name>` run in your working tree with `test` (all)
or `test <name> [args]`, and sandboxed against the flake's source as `checks.<system>.test-<name>`
in `nix flake check` and CI.
Plugins add their own (see the Tests column above); so can you:

```nix
perSystem = { pkgs, ... }: {
  nullkomma.tests.greeting = {
    packages = [ pkgs.hello ];
    command = "hello | grep -q Hello";
  };
};
```

### Websites

Opt-in `quarto` renders the project into `packages.site` (`nix build .#site`);
`preview` serves it locally and reloads on edits.
Shared Quarto extensions, e.g. from a brand flake, go in `nullkomma.quarto.extensions.<name>`.
The `r` plugin builds a [pkgdown site](#pkgdown-website) into `packages.site` instead;
if both are enabled, set `perSystem.packages.site` yourself.

#### Brand

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
Its privacy sections join every site's privacy policy; pkgdown also applies its theme and footer.

#### Privacy policy

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

#### Deploying to Cloudflare

Opt-in `cloudflare` serves whatever `packages.site` holds as [Workers static assets][cloudflare],
deployed with [Terranix], including custom domains, `_headers` and `_redirects`; `workers.dev` is disabled.

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

## Files in your repository

nullkomma keeps files in your repository to a minimum; features live in Nix.
Some tools still need real files (Git needs `.gitignore`, GitHub needs workflows,
editors need settings). Each is one of two kinds:

|                             | **Source of truth** (committed, yours to edit) | **Generated from Nix** (Git-ignored, don't edit) |
| --------------------------- | ---------------------------------------------- | ------------------------------------------------ |
| `nix flake init --template` | `flake.nix`, `.envrc`                          | (not possible)                                   |
| `write-files`               | `.gitignore`, GitHub workflows                 |                                                  |
| `generate-files`            |                                                | `.vscode/*.json`, `.nvim.lua`, Quarto extensions |

Templates can't take parameters, so anything that depends on your configuration
comes from `write-files` or `generate-files`.

### Source-of-truth files

`write-files` writes these once (`nullkomma.files."<path>".mode = "source"`, the default);
then they are yours to edit and commit.
When nullkomma later changes a file, `write-files` updates it only if you haven't edited it.
Otherwise it keeps your version, saves the new one next to it and fails,
pointing you to the [resolve-file-conflicts skill](#resolving-conflicts).
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

## Languages

### R

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
Outside Nix, `r-lock` and [`r-non-nix`](#without-nix) install from the [PPM] snapshot
of the same date (`nullkomma.r.snapshot`), so every environment gets packages that were on CRAN together.

`Depends`, `Imports`, `LinkingTo`, `Suggests` and all `Config/Needs/*` fields are locked,
e.g. `Config/Needs/development: devtools`; override `nullkomma.r.fields` for a runtime-only lockfile.
The development environment adds pak, languageserver and the tools of enabled workflows;
`nullkomma.r.extraPackages` adds other Nix-only packages.

> [!NOTE]
> Packages from `Remotes`, or missing from `nixpkgs-r`, need `nullkomma.r.allowOffNixpkgs = true`.
> Git sources use the locked commit;
> URL sources also need `nullkomma.r.hashes.<package>` from `nix store prefetch-file <url>`.
> Add missing system libraries with `perSystem.nullkomma.r.buildInputs.<package>`.
> GitLab and local references are unsupported; use `git::` for GitLab.

#### Tasks and tests

| Command                     | What it does                                                            | Opt out                                                           |
| --------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `r-document`                | Generate `man/*.Rd` and `NAMESPACE` with roxygen2                       | `nullkomma.r.document.enable` (for hand-written manuals)          |
| `test r-cmd-check`          | Build and run rcmdcheck                                                 | `nullkomma.r.check.enable`                                        |
| `test r-testthat`           | Run testthat on the source                                              | `nullkomma.r.testthat.enable`                                     |
| `test r-testthat-installed` | Install into a temporary library and run testthat on the installed copy | `nullkomma.r.testthat.enable`                                     |
| `test r-namespace`          | Fail if roxygen2 would change the committed `NAMESPACE`                 | with `r-document`                                                 |
| `r-pkgdown`                 | Build the [website](#pkgdown-website) into `docs/`                      | `nullkomma.r.pkgdown.enable`                                      |
| `r-coverage`                | Write a local Cobertura `coverage.xml` with covr                        | off unless covr is locked or `nullkomma.r.coverage.enable = true` |

Checks, tests and site builds regenerate documentation first.
Generated `man/*.Rd` files are Git-ignored, but not `man/` itself; commit `NAMESPACE`.
`nullkomma.r.check.errorOn` sets the failing severity (default `"note"`).
The `r` plugin keeps its package-build exclusions in a marked section of `.Rbuildignore`.

Run tests [in parallel](https://testthat.r-lib.org/articles/parallel.html), with and without Nix,
by committing these to `DESCRIPTION` (or running `usethis::use_testthat(3, parallel = TRUE)`):

```dcf
Config/testthat/edition: 3
Config/testthat/parallel: true
```

Declaring [shinytest2](https://rstudio.github.io/shinytest2/) adds Chromium on Linux and points chromote at it.
Nix builds disable Chromium's sandbox, which can't nest in the build sandbox.
Nixpkgs has no Chromium for macOS: there chromote finds your Chrome, or uses `CHROMOTE_CHROME`.
`perSystem.nullkomma.r.browser` selects another browser.

#### pkgdown website

`packages.site` builds the [pkgdown](https://pkgdown.r-lib.org) site in the sandbox,
also in `nix flake check`; `r-pkgdown` builds it locally.
[Cloudflare](#deploying-to-cloudflare) can publish it.

- A patch skips pkgdown's online CRAN/Bioconductor lookup; add those links with `home.links`.
- Bootstrap 5's JavaScript dependencies are pinned in nullkomma.
  Other remote templates, web fonts and network-dependent articles must be local for the sandbox.
- `nullkomma.r.pkgdown.config` is merged over `_pkgdown.yml` in both builds,
  overriding the [brand](#brand); sandbox-only `pkgdown.override` wins over both.
- `nullkomma.r.pkgdown.assets` is a directory generated into Git-ignored `pkgdown/assets/`,
  which pkgdown copies to the site root; leave it `null` to manage that directory yourself.
- The [privacy policy](#privacy-policy) is generated into Git-ignored `.github/privacy.md`, which pkgdown renders to `/privacy.html`;
  set `nullkomma.r.pkgdown.privacy.page = null` to write your own.

#### Formatting and tools

[Air] formats R and [Jarl] lints and fixes it first, configured by `jarl.toml`
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

#### Without Nix

For collaborators without Nix, enable `nullkomma.r-non-nix.enable = true` (it enables `r`),
run `write-files`, and commit `.Renviron`, `.Rprofile`, `.R/install.R`, `.Rbuildignore`
and the [R development without Nix](modules/lang/r-non-nix/_assets/development.md) section added to your README.
These are [source-of-truth files](#source-of-truth-files).
The startup profile only acts in native R sessions, installing from the same PPM snapshot
(`nullkomma.r.snapshot`, `nullkomma.r.ppmUrl`); it leaves Nix shells, builds and tasks alone.

## Design

Each column of the [Plugins](#plugins) table is a framework: options (in `perSystem`,
except `nullkomma.gitignore`) that plugins fill in, and so can you.
Most plugins feed columns; a few render them (`git`, `vscode`, `neovim`) or run them (`treefmt`).

| Column        | Options                                                        | Task                            | Ends up in                                                             |
| ------------- | -------------------------------------------------------------- | ------------------------------- | ---------------------------------------------------------------------- |
| Dev helpers   | `nullkomma.devHelpers`                                         |                                 | dev shell                                                              |
| Format / lint | `treefmt.programs`                                             | `format`                        | `nix fmt`, `checks.<system>.treefmt`, editors                          |
| Tests         | `nullkomma.tests.<name>`                                       | `test`                          | `checks.<system>.test-<name>`                                          |
| Files         | `nullkomma.files.<path>` (and top-level `nullkomma.gitignore`) | `write-files`, `generate-files` | the repository                                                         |
| Editor        | `nullkomma.editor`                                             |                                 | language servers and formatter in the dev shell; editor plugins' files |

Tasks (`nullkomma.tasks.<name>`) aren't a column: they're the command layer under the columns.

Independent plugins do not read each other's options. Values shared between plugins are
framework options that any plugin may set or read. For example, `treefmt` sets
`nullkomma.editor.formatter` and the `nix` language server uses it, without
knowing which plugin set it. Another formatter plugin can replace `treefmt`
without changing `nix`.

A companion plugin may import and enable its base plugin and reuse its options:
`r-non-nix` depends on `r`, but `r` does not depend on the compatibility layer.

## Development

Before building something, check [flake.parts](https://flake.parts) for an
existing module; see [AGENTS.md](AGENTS.md). Inputs only nullkomma's own
development needs go in [`dev/flake.nix`](dev/flake.nix), so they stay out of
projects' `flake.lock`.

### Testing nullkomma

nullkomma is tested against small example projects ("fixtures") in
`tests/fixtures`, which use nullkomma the way a real project would.

- **Unit tests** ([nix-unit], via the `nix` plugin) check
  the evaluated configuration of the fixtures, e.g. that every plugin can be
  switched off and that all off leaves just the framework. This repo's unit
  check uses the Nix plugin's network-enabled fixed-output derivation to fetch
  dev-only partition inputs, which root input overrides cannot replace.
- **Docs test:** `options-doc` renders every option the way
  [flake.parts](https://flake.parts) would, so each needs a description.
- **Build tests** run the real tools on the fixtures inside `nix flake check`:
  valid files must pass, and for every formatter/linter plugin a deliberately
  bad file (listed in `rejects`) must fail with that tool's error.
- **End-to-end test:** `check-fixtures` copies a fixture to a temporary
  directory and runs `nix flake check` there (with valid and bad files), exactly
  as a user would, against this checkout of nullkomma. The other tests evaluate fixtures from within
  nullkomma's own flake, so only this one catches problems with
  how a real project fetches and uses nullkomma. CI runs it on every push.
- **Without Nix:** `test-r-non-nix` builds the `r-non-nix` fixture in Docker
  (Ubuntu 24.04, `linux/amd64`, the R version of `nixpkgs-r`, no Nix), runs the
  documented R examples and checks a source-package build. It needs Docker and network
  access; extra arguments go to `docker build`, e.g.
  `--build-arg R_VERSION=4.4.2`. CI runs it on manual dispatch.

```sh
nix flake check   # unit, docs and build tests
check-fixtures    # end-to-end test
test-r-non-nix    # R without Nix, in Docker
```

New plugins should add a valid and a deliberately broken fixture, and check that
the broken one fails with the real tool's error, not just any error.

`pkgdown-dependencies` refreshes the pinned pkgdown Bootstrap 5 dependencies.

[air]: https://posit-dev.github.io/air/
[bash]: https://www.gnu.org/software/bash/
[bash ide]: https://marketplace.visualstudio.com/items?itemName=mads-hartmann.bash-ide-vscode
[bash-language-server]: https://github.com/bash-lsp/bash-language-server
[bats]: https://bats-core.readthedocs.io
[cloudflare]: https://developers.cloudflare.com/workers/static-assets/
[direnv]: https://direnv.net
[flakehub]: https://flakehub.com
[gha]: https://docs.github.com/actions
[git]: https://git-scm.com
[gitleaks]: https://github.com/gitleaks/gitleaks
[jarl]: https://jarl.etiennebacher.com
[jscpd]: https://github.com/kucherenko/jscpd
[json]: https://www.json.org
[jsonls]: https://github.com/hrsh7th/vscode-langservers-extracted
[keep-sorted]: https://github.com/google/keep-sorted
[marksman]: https://github.com/artempyanykh/marksman
[md]: https://commonmark.org
[neovim]: https://neovim.io
[nix]: https://nixos.org
[nix environment selector]: https://marketplace.visualstudio.com/items?itemName=arrterian.nix-env-selector
[nix ide]: https://marketplace.visualstudio.com/items?itemName=jnoortheen.nix-ide
[nix-direnv]: https://github.com/nix-community/nix-direnv
[nix-unit]: https://github.com/nix-community/nix-unit
[nixd]: https://github.com/nix-community/nixd
[pak]: https://pak.r-lib.org
[ppm]: https://packagemanager.posit.co
[quarto]: https://quarto.org
[r]: https://www.r-project.org
[terranix]: https://terranix.org/flake-parts.html
[toml]: https://toml.io
[treefmt]: https://treefmt.com
[typos]: https://github.com/crate-ci/typos
[up]: https://github.com/DeterminateSystems/up
[vscode]: https://code.visualstudio.com
[vscode-bats]: https://marketplace.visualstudio.com/items?itemName=jetmartin.bats
[vscode-quarto]: https://marketplace.visualstudio.com/items?itemName=quarto.quarto
[vscode-treefmt]: https://marketplace.visualstudio.com/items?itemName=ibecker.treefmt-vscode
[vscode-yaml]: https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml
[yaml]: https://yaml.org
[yaml-language-server]: https://github.com/redhat-developer/yaml-language-server
[`fh`]: https://github.com/DeterminateSystems/fh
[`flake-checker`]: https://github.com/DeterminateSystems/flake-checker
