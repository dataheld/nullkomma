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

## Installing

> [!TIP]
> The steps below are **system / user** prerequisites.
> Project-specific software is handled by the flake once you are inside the repo.

1. Install Nix (the package manager).
   The [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer) is recommended.

1. For automatic flake-shell activation, provide [direnv](https://direnv.net) and [nix-direnv](https://github.com/nix-community/nix-direnv) in your user environment (managed via [lap](https://github.com/dataheld/lap) or installed manually).

   > [!TIP]
   > `nix-`/`direnv` can be a bit chatty on launch.
   > Set [`hide_env_diff=true`](https://direnv.net/man/direnv.toml.1.html) to quiet it down.

1. In your project, add a `flake.nix` from the `default` template:

   ```sh
   nix flake init --template "https://flakehub.com/f/dataheld/nullkomma/0.1.*#default"
   ```

   The template also includes `.envrc` containing `use flake`.
   Existing files are preserved.

   Its `nixpkgs.follows = "nullkomma/nixpkgs"` uses nullkomma's tested Nixpkgs
   pin and lets `flake-checker` check it. To use your own Nixpkgs instead,
   declare `nixpkgs.url` and set `nullkomma.inputs.nixpkgs.follows = "nixpkgs"`.

1. Initialize remaining missing files (see below):

   ```sh
   git add flake.nix .envrc
   nix develop --command write-files
   nix develop --command generate-files
   ```

1. (one-time only) Inside the repo, run `direnv allow`.

> [!TIP]
> Windows is not supported by Nix,
> but you can use the
> [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install).

From now on, whenever you change into the directory of your project,
all the necessary dependencies etc. will be ready.
The first time you enter the directory, this might take some time.

## Using

Project tasks are plain commands in the development shell (they accept
arguments, e.g. `write-files --accept <path>`). The
[DeterminateSystems/up](https://github.com/DeterminateSystems/up) runner lists
them and runs them without arguments:

```sh
tasks          # list tasks
tasks check    # run one task
tasks all      # run all tasks that don't change files
```

### Plugins

Everything nullkomma adds comes from **plugins**, exported as flake-parts modules
`flakeModules.<plugin>` next to the shared `flakeModules.framework`.
All plugins are optional; `nullkomma.lib.mkFlake` (or importing
`flakeModules.default` into your own `flake-parts.lib.mkFlake`) enables the
ones below by default (except opt-in ones), so you only list exceptions:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.github.enable = false;
  nullkomma.markdown.enable = false;
}
```

| Plugin                              | Dev helpers    | Format / lint          | Tests                                                             | Files                                                              | Editor                                                           |
| ----------------------------------- | -------------- | ---------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------- |
| [`nix`][nix]                        |                | ✅, [`flake-checker`]¹ | [nix-unit]²                                                       | ignores `result`                                                   | [nixd]; VS Code: [Nix IDE]                                       |
| [`markdown`][md]                    |                | ✅                     |                                                                   |                                                                    | [marksman]                                                       |
| [`json`][json]                      |                | ✅                     |                                                                   |                                                                    | [JSON language server][jsonls]                                   |
| [`yaml`][yaml]                      |                | ✅                     |                                                                   |                                                                    | [yaml-language-server]; VS Code: [YAML][vscode-yaml]             |
| [`toml`][toml]                      |                | ✅                     |                                                                   |                                                                    |                                                                  |
| [`shell`][bash]                     |                | ✅³                    | [bats]³                                                           |                                                                    | [bash-language-server]; VS Code: [Bash IDE], [Bats][vscode-bats] |
| [`github`][gha]                     |                |                        |                                                                   | `push.yml`⁴                                                        |                                                                  |
| [`keepSorted`][keep-sorted]         |                | ✅                     |                                                                   |                                                                    |                                                                  |
| [`gitleaks`][gitleaks]              | secret-history | ✅ secrets             |                                                                   |                                                                    |                                                                  |
| [`typos`][typos]                    |                | ✅ spelling⁷           |                                                                   |                                                                    |                                                                  |
| [`jscpd`][jscpd]                    |                |                        | duplicated code                                                   |                                                                    |                                                                  |
| [`treefmt`][treefmt]                |                | runs all ✅            |                                                                   |                                                                    | formatter; VS Code: [treefmt][vscode-treefmt]                    |
| [`git`][git]                        | git            |                        |                                                                   | `.gitignore`                                                       |                                                                  |
| [`direnv`][direnv]                  |                |                        |                                                                   | `.envrc`, ignores `.direnv/`                                       | VS Code: [Nix Environment Selector]                              |
| [`vscode`][vscode]                  |                |                        |                                                                   | `.vscode/`⁵                                                        | renders it for VS Code⁵                                          |
| [`neovim`][neovim]                  |                |                        |                                                                   | `.nvim.lua`⁵                                                       | renders it for Neovim⁵                                           |
| [`flakehub`][flakehub]              | [`fh`]         |                        |                                                                   |                                                                    |                                                                  |
| [`quarto`][quarto] (opt-in)         | quarto⁹        |                        |                                                                   | ignores `.quarto/`, `_site/`; `_extensions/`⁸, `privacy.qmd`⁸      | VS Code: [Quarto][vscode-quarto]                                 |
| [`cloudflare`][cloudflare] (opt-in) | wrangler⁶      |                        | OpenTofu validation                                               | ignores `.nullkomma/cloudflare/`                                   |                                                                  |
| [`r`][r] (opt-in)                   | R, pak         | ✅                     | strict rcmdcheck, parallel testthat, pkgdown, namespace freshness | `.Rbuildignore`, R ignores, `.github/privacy.md`⁸, pkgdown assets⁸ | R languageserver; VS Code: R, Air                                |
| `r-non-nix` (opt-in, enables `r`)   |                |                        |                                                                   | `.Rprofile`, `.Renviron`, `.R/install.R`, README                   |                                                                  |

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
to the privacy policy (see [Static websites](#static-websites)).

⁷ Skips translations such as `*.de.md`, one pattern per non-English
`nullkomma.privacy.languages`; typos only knows English.

⁸ Generated: `nullkomma.quarto.extensions`, `nullkomma.r.pkgdown.assets`, and
the privacy policy once there are `nullkomma.privacy.sections`.

⁹ Also adds the `preview` task: `quarto preview`, serving the site on localhost
and re-rendering and live-reloading it on changes.

✅ means the plugin's files are formatted/linted by the `format` task (or `nix fmt`) and
checked by `nix flake check` (via treefmt). The exact tools are in the plugin's source.

Markdown and YAML linting run after their formatters, through the same treefmt
commands and editor integration. Commit ordinary native config files to extend
shared defaults; nullkomma does not generate or overwrite these files. See
[Customizing linting](#customizing-linting) for configuration, precedence and
exclusions. Without project configuration, YAML uses relaxed rules without a
line-length limit.

Generated outputs are not formatted or linted: managed files and entire managed
directories are excluded, along with R/pkgdown and Quarto build outputs. Add
repository-relative treefmt globs to `nullkomma.generatedPaths` for other generated
content, for example `[ "generated/**" ]`. These are treefmt globs, not Git ignore
patterns; hand-maintained sources such as `man/figures/` remain included.

### Customizing linting

Prefer a committed native file for project-specific settings:

| Tool         | Native configuration                                                                        | How it combines with shared policy                                                                                                                                                                                                                                  |
| ------------ | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| typos        | `.typos.toml`, `typos.toml`, `_typos.toml`, or `[tool.typos]` in `pyproject.toml`           | Native discovery adds words, file types and `files.extend-exclude`; explicit shared settings win conflicting keys, following typos' `--config` precedence.                                                                                                          |
| markdownlint | `.markdownlint.{jsonc,json,yaml,yml,cjs,mjs}` and `.markdownlint-cli2.{jsonc,yaml,cjs,mjs}` | Project rules override shared rules by rule name; other shared rules remain. CLI2 `ignores` and native nested discovery work normally; project `globs` cannot expand treefmt's selected files.                                                                      |
| yamllint     | `.yamllint`, `.yamllint.yaml`, `.yamllint.yml`                                              | Project rules extend shared rules (including per-rule settings); project and shared ignore patterns are retained. Native discovery searches the working directory and parents, not per-file subdirectories. Explicit native `extends` still applies before merging. |
| Jarl         | `jarl.toml`                                                                                 | Native only: nullkomma passes no shared Jarl settings.                                                                                                                                                                                                              |
| ShellCheck   | `.shellcheckrc` and source directives                                                       | Native settings supplement command-line defaults.                                                                                                                                                                                                                   |
| actionlint   | `.github/actionlint.yaml` or `.github/actionlint.yml`                                       | Native repository configuration.                                                                                                                                                                                                                                    |
| jscpd        | `.jscpd.json`, `.config/jscpd.json`, or the `jscpd` key in `package.json`                   | Project `ignore` globs add to the shared exclusions; other settings win, e.g. `threshold` (a percentage, default 0) or `"formatsExts": { "nix": ["nix"] }` to also scan Nix files.                                                                                  |
| gitleaks     | `.gitleaks.toml`, `.gitleaksignore`                                                         | Include `[extend]` with `useDefault = true` in a native TOML config to retain upstream detection rules; add project rules or allowlists normally.                                                                                                                   |

For example, add spellings and skip a vendor directory in `.typos.toml`:

```toml
[default.extend-words]
foobaar = "foobaar"

[files]
extend-exclude = ["vendor/**"]
```

Add `MD042: false` in `.markdownlint.yaml` to disable that rule without losing
shared Markdown policy. In `.yamllint`, `rules: {quoted-strings: {required: true}}`
adds a rule without restoring the shared-disabled line-length limit.

For reusable policy in Nix, set `nullkomma.lint.typos`,
`nullkomma.lint.markdown` or `nullkomma.lint.yaml`.
These settings merge through the module system; override the shared typos
`type.r-description.extend-words.fnd` setting there if needed. Native files are
user-owned and are not reformatted into a generated combined config. Without Nix,
linters see only their native files, not nullkomma's shared policy.

Tools without native config files (for example deadnix) use treefmt-nix options;
no universal linter config format is imposed. The same interface also adds
arguments and exclusions for any formatter/linter:

```nix
perSystem = { ... }: {
  treefmt.programs.deadnix.no-lambda-arg = true;
  treefmt.settings.formatter.typos.excludes = [ "snapshots/**" ];
  treefmt.settings.excludes = [ "vendor/**" ];
};
```

Use each tool's `perSystem.treefmt.programs.<name>` options for supported settings
and `treefmt.settings.formatter.<name>.options` for extra command-line arguments.
A committed `treefmt.toml` is **not** merged: treefmt-nix supplies its generated
configuration explicitly. Replacing a tool's `package` or typos' `configFile`, or
enabling typos' `isolated`, opts out of the corresponding shared/native merging.
Linter ignores affect that linter only; treefmt exclusions skip formatters too.

Every test runs locally with `test` (or `test <name> [args]`) and, sandboxed
against the flake's source, as `checks.<system>.test-<name>` in
`nix flake check` and CI.

Each column is a framework: options (in `perSystem`, except `nullkomma.gitignore`)
that plugins fill in, and so can you. Most plugins feed columns; a few render
them (`git`, `vscode`, `neovim`) or run them (`treefmt`). Independent plugins read
framework options; companion plugins can explicitly depend on a base plugin.

| Column        | Options                                                        | Task                            | Ends up in                                                             |
| ------------- | -------------------------------------------------------------- | ------------------------------- | ---------------------------------------------------------------------- |
| Dev helpers   | `nullkomma.devHelpers`                                         |                                 | dev shell                                                              |
| Format / lint | `treefmt.programs`                                             | `format`                        | `nix fmt`, `checks.<system>.treefmt`, editors                          |
| Tests         | `nullkomma.tests.<name>`                                       | `test`                          | `checks.<system>.test-<name>`                                          |
| Files         | `nullkomma.files.<path>` (and top-level `nullkomma.gitignore`) | `write-files`, `generate-files` | the repository                                                         |
| Editor        | `nullkomma.editor`                                             |                                 | language servers and formatter in the dev shell; editor plugins' files |

Tasks (`nullkomma.tasks.<name>`) aren't a column: they're the command layer
under the columns. Each becomes a dev shell command and an entry in the `tasks`
runner; plugins add a few more of their own (see the footnotes).

The dev shell (`devShells.default`) is assembled from these: task commands,
editor tools and dev helpers. Packages a test or task needs (e.g. bats and the
tools your bats tests call) stay inside that test or task, off your `PATH`.

### Knobs

Options live under `nullkomma.*`, for example:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.github.ci.inputs.visibility = "public"; # publish to FlakeHub
  perSystem =
    { pkgs, ... }:
    {
      nullkomma.devHelpers = [ pkgs.hello ];
      treefmt.programs.typos.enable = true;
    };
}
```

### Static websites

Opt-in `quarto` renders the project into `packages.site`; opt-in `cloudflare`
serves whatever `packages.site` holds as [Workers static assets][cloudflare].
Use either with another builder or host.

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.quarto.enable = true;
  nullkomma.cloudflare = {
    enable = true;
    worker = "my-site";
    domains."www.example.org" = "<zone ID>";
  };
}
```

In `nix develop`, run `preview` to serve the site on localhost; Quarto
re-renders and reloads the page as you edit.

Shared Quarto extensions, e.g. a brand from another flake, go in
`nullkomma.quarto.extensions.<name>`: generated into `_extensions/<name>` and
copied into the build.

Plugins that set up processing of visitors' data add a section to
`nullkomma.privacy.sections` (`cloudflare` adds one on hosting and analytics);
so can a brand module or the project:

```nix
nullkomma.privacy.sections.booking = {
  order = 500; # cloudflare is 200
  markdown = {
    en = ./booking.en.md;
    de = ./booking.de.md;
  };
};
```

`quarto` renders them, by `order`, into `privacy.qmd`
(`nullkomma.quarto.privacy.page`), one tab per `nullkomma.privacy.languages`.
Link it from your footer. To write your own, set the page to `null`; other
builders get the sections' files from the same option.
nullkomma's sections are a starting point, not legal advice.

In `nix develop`, use `tasks` to select `terraform` (plan changes) or `deploy`
(publish). Run `terraform <command> [args]` for other OpenTofu commands.
Deployment uses [Terranix], including custom domains, `_headers` and `_redirects`;
`workers.dev` is disabled. In CI, use `nix run .#deploy`.

Set these variables for an existing private R2 state bucket; in GitHub Actions:

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

### R projects

Enable `nullkomma.r.enable = true` (or use the `r` template).

Dependencies are *declared* in `DESCRIPTION`.
But because the `DESCRIPTION` alone does *not* record a reproducible R environment,
dependencies are resolved and locked via [pak](https://pak.r-lib.org)'s `pkg.lock`.
Nix reads the package names from `pkg.lock` and uses the versions and build
instructions from the Nixpkgs revision recorded in `flake.lock`, rather than
pak's recorded versions. With `allowOffNixpkgs` enabled, packages unavailable
there or explicitly pinned in `Remotes` instead use the source revisions or
download hashes recorded in `pkg.lock` and the flake configuration.

After direnv loads the development shell, use `r-lock` to refresh dependencies:

```sh
r-lock
git add DESCRIPTION pkg.lock
```

Run it after dependency changes and Nix updates. For the first setup, if
`DESCRIPTION` exists but `pkg.lock` does not, run `nix run .#r-lock` once:
the development shell needs the lockfile before direnv can load it.

The `r` plugin keeps its exclusions in a marked section of `.Rbuildignore`, next
to your own rules; run `write-files` and commit it. They apply to package checks
inside and outside Nix.

#### Package development tasks

| Command                     | What it does                                                                | Enabled when                                                                        |
| --------------------------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `r-document`                | Generate `man/*.Rd` and `NAMESPACE` with roxygen2                           | Always; disable with `nullkomma.r.document.enable = false` for hand-written manuals |
| `test r-cmd-check`          | Generate documentation, build, and run rcmdcheck                            | Default on; `nullkomma.r.check.enable`                                              |
| `test r-testthat`           | Generate documentation and run parallel testthat on the development source  | Default on; `nullkomma.r.testthat.enable`                                           |
| `test r-testthat-installed` | Install into a temporary library and test the installed package in parallel | Default on; `nullkomma.r.testthat.enable`                                           |
| `test r-namespace`          | Fail if roxygen2 would change the committed `NAMESPACE`                     | With `r-document`                                                                   |
| `r-pkgdown`                 | Build a website in `docs/` without opening a browser                        | Default on; `nullkomma.r.pkgdown.enable`                                            |
| `r-coverage`                | Write a local Cobertura `coverage.xml` report with covr                     | covr is locked or `nullkomma.r.coverage.enable = true`                              |

`test <name>` runs one test suite in the working tree; `nix flake check` runs
them all, sandboxed, as `checks.<system>.test-<name>`.

Documentation is regenerated before checks, tests and website builds. Generated
`man/*.Rd` files are Git-ignored, **not** the whole `man/` directory: keep
hand-maintained figures.
Commit `NAMESPACE`; `test r-namespace` rejects stale
exports.
testthat runs against both the development and installed package in
`nix flake check`. Package dependencies remain in DESCRIPTION; nullkomma adds
only the tools needed by enabled workflows to the development R environment,
not to deployable package outputs. Set any workflow's `enable` option to `false`
to opt out; `nullkomma.r.check.errorOn = "warning"` relaxes the note threshold.

Test files run in parallel in source tests, installed tests and R CMD check.
`TESTTHAT_CPUS` defaults to Nix's `NIX_BUILD_CORES` allocation, or two locally;
a one-core allocation is respected. Override it to choose a worker count, or use
`TESTTHAT_PARALLEL=false` for a single serial invocation. Set
`nullkomma.r.testthat.parallel = false` for the project's default opt-out.

nullkomma uses testthat's native environment controls, without rewriting
`DESCRIPTION` or changing the test edition. Use edition 3 for upstream-supported
parallel testing. To enable parallelism outside the Nix environment too, commit:

```dcf
Config/testthat/edition: 3
Config/testthat/parallel: true
```

With pkgdown enabled, `nix build .#site` produces the website and
`nix flake check` builds it too. The existing Cloudflare plugin can publish this
same `packages.site` output; no R-specific deployment pipeline is needed.
Both builds keep pkgdown's metadata-generated sidebar: source and bug-report
links, license, citation and authors come from the package itself. When pkgdown
is enabled, nullkomma applies a small Nix package patch to skip only its online
CRAN/Bioconductor repository discovery. Automatic “View on CRAN/Bioconductor”
links are omitted; add any known repository links through native `home.links`
settings instead. Sidebar ordering, custom components, `home.sidebar = false`
and local `home.sidebar.html` overrides keep their usual pkgdown behavior.
pkgdown defaults to Bootstrap 5 (`template.bootstrap`); Bootstrap 3 templates
load their assets from CDNs. Bootstrap 5's JavaScript dependencies (including
Headroom and search) are pinned in nullkomma and fetched by Nix, not by R during
the build; maintainers refresh the pins with the `pkgdown-dependencies` task. Remote templates,
web fonts and network-dependent articles must still be supplied locally for a
reproducible Nix build. If both Quarto and pkgdown are enabled, select the intended
`perSystem.packages.site` explicitly.

To use a brand flake, declare its input and select it:

```nix
inputs.brand = {
  url = "https://flakehub.com/f/dataheld/brand/0.1.*";
  inputs.nullkomma.follows = "nullkomma";
};
# Inside mkFlake's module:
nullkomma.brand = inputs.brand;
```

The brand supplies `lib.brand` (a brand.yml path), optionally `lib.footer` (HTML)
and `flakeModules.privacy`. Its privacy sections join `nullkomma.privacy` for
every site plugin; pkgdown also applies its theme and footer in both builds. Footer wrappers are converted to divs
so they do not nest inside pkgdown's own footer. No additional imports or
integration tests are needed in the consumer.

`nullkomma.r.pkgdown.config` supplies native pkgdown settings to both
`r-pkgdown` and the sandboxed build, merged over the project's `_pkgdown.yml`.
Its settings override brand defaults. Without a brand flake, use
`template.bslib.brand` for a local `_brand.yml` path (automatically adding
the `brand.yml` R package), and `footer.structure`/`footer.components` for shared
footer markup. Sandbox-only `pkgdown.override` settings take precedence.
Shared images and other site files
go in `pkgdown.assets`, a directory generated into Git-ignored `pkgdown/assets/`
and copied by pkgdown to the website root; it is excluded from package tarballs.
The pkgdown workflows refuse existing project-owned assets and symlinks; leave
this option `null` to keep managing `pkgdown/assets/` yourself. Like other
generated directories, `generate-files` replaces untracked contents at that path.
Branding remains a consumer input,
not a dependency of nullkomma.

pkgdown also renders `nullkomma.privacy.sections`, including hosting and brand
sections, to `privacy.html`. Both the local task and the sandboxed build generate
Git-ignored `.github/privacy.md`, excluded from R package tarballs, where pkgdown
finds it natively, with or without Nix, and renders it to the root-level
`/privacy.html` URL. Sections follow their
configured order; each must provide every configured privacy language. Multiple
languages appear in expandable sections without extra JavaScript or dependencies.
Set `nullkomma.r.pkgdown.privacy.page = null` to supply your own page, or choose
another Markdown filename in `.github/` or the package root. Project-owned files,
symlinked sources and conflicting root, `.github/` or asset pages are refused.
When upgrading from `pkgdown/privacy.md` or root-level `privacy.md`, remove that
old generated file before building; it is not deleted automatically.
Link to the HTML page from your pkgdown navigation or brand footer.

Declaring shinytest2 in DESCRIPTION (and refreshing `pkg.lock`) also supplies
Chromium on Linux and configures chromote for the devshell, checks, and tasks.
The browser is headless and managed by shinytest2; no background browser service
is needed. In Nix builds only, Chromium's namespace sandbox is disabled because
it cannot nest inside the build sandbox; it stays enabled for interactive use.
macOS has no Nixpkgs Chromium package: local tasks use chromote's installed
Chrome discovery, or `CHROMOTE_CHROME`; run hermetic browser checks on Linux.
`perSystem.nullkomma.r.browser` can select another Nix-packaged browser.
The Linux `r-shinytest2` fixture check drives a real app, changes an input,
asserts the reactive output and browser user agent, and fails if tests skip.

#### Upstream R tooling choices

These workflows cover the R-specific targets of
[crow's Makefile](https://github.com/dataheld/crow/blob/main/Makefile) and
[CI](https://github.com/dataheld/crow/blob/main/.github/workflows/cicd.yaml):
documentation, namespace freshness, checks, local/installed tests, linting and
pkgdown publication. Nix replaces its dependency/system-library installation;
the existing treefmt and Cloudflare integrations replace separate lint/deploy
pipelines. Its Docker images, Make wrappers and container health checks are
intentionally not reproduced.

Current representative tidyverse/r-lib repositories still use
[rcmdcheck](https://github.com/r-lib/actions/blob/v2/examples/check-standard.yaml),
[roxygen2](https://github.com/r-lib/actions/blob/v2/examples/document.yaml),
[pkgdown](https://github.com/r-lib/actions/blob/v2/examples/pkgdown.yaml),
[lintr](https://github.com/r-lib/devtools/blob/main/.github/workflows/lint.yaml)
and [covr/Cobertura](https://github.com/r-lib/actions/blob/v2/examples/test-coverage.yaml).
[dplyr's Air workflow](https://github.com/tidyverse/dplyr/blob/main/.github/workflows/format-suggest.yaml)
confirms Air is a current choice, rather than adding styler as a second formatter.
nullkomma lints with [Jarl](https://jarl.etiennebacher.com) instead of lintr:
it needs no package load and fixes lints before Air formats. Coverage remains
optional. Coverage reporting stays local: no Codecov account,
token or upload is required. Upstream's Windows and R release/devel/oldrel
matrices test compatibility beyond our one locked R version; Nix does not
replace those when a project needs them.

pak and languageserver are always included. Declare test dependencies such as
testthat in `DESCRIPTION`'s `Suggests` field, which is included by default.
For development-only tools, use pak's `Config/Needs/development` field:

```dcf
Config/Needs/development: devtools
```

All `Config/Needs/*` fields are included automatically; run `r-lock` after edits.
For a runtime-only environment, override `nullkomma.r.fields` with
`[ "Depends" "Imports" "LinkingTo" ]` and generate a separate lockfile.
Production package outputs should use `buildRPackage` with only their required
dependencies, not the development R environment; see the `r-production` fixture,
whose package output excludes testthat, pak, languageserver and development tools.

Reserve `nullkomma.r.extraPackages` for Nix-only additions, not shared project
dependencies.

nullkomma will automatically set a snapshot date for R package sources to retrieve from [Posit's Public Package Manager (PPM)](https://packagemanager.posit.co).

This gets you two benefits:

1. All R packages come at the version, in which they were all on CRAN (and, by extension, PPM) on *some* defined day.
   Packages on CRAN at the same time are known to work together as well as working with the version of R released at that time.
   These compatibility guarantees are rare in software ecosystems and should be maintained in your project.
   This date will be set by the Nixpkgs set in your nullkomma (see next point).
1. Nix brings the correct version of R, as well as the system dependencies known to work with these versions of the R packages.
   This too improves compatibility, because the nix project has run tests on the R packages, including the available system dependencies in nixpkgs for that release.

> [!TIP]
> If you need a more current version of R or its packages than are included in the current nixpkgs,
> you can override it by setting `inputs.nullkomma.inputs.nixpkgs-r.url`.

> [!INFO]
> If you "hand-pick" a package using the `DESCRIPTION`s `Remotes:` field
> (which be pinned *or* float!)
> nix will download the source based on that information lock down the compute environment based on that download (a hash).
> Such `Remotes:`-packages require `nullkomma.r.allowOffNixpkgs = true`.
> Git sources use the locked commit; URL sources also require `nullkomma.r.hashes.<package>` from
> `nix store prefetch-file <url>`.
> These packages build against the selected R package set. Add missing system libraries through
> `perSystem.nullkomma.r.buildInputs.<package>`.
> GitLab-specific and local
> references are unsupported; use `git::` for GitLab repositories.

[Posit's Air](https://posit-dev.github.io/air/) extends treefmt for R by default.
The editor-neutral R language server defers formatting
to the configured editor formatter, when present. [Jarl](https://jarl.etiennebacher.com)
lints and auto-fixes R before Air runs, through treefmt, configured only by the
project's own `jarl.toml`; disable it with `nullkomma.r.jarl.enable = false`. On
macOS it builds from source with upstream tests disabled.
R projects also allow HTML and unrestricted line length in Markdown (`MD033` and
`MD013`). testthat snapshots and generated `docs/` are in
`nullkomma.generatedPaths`, so they need no separate linter exceptions.
The valid author role `fnd` is protected from typos corrections in `DESCRIPTION`
files, without accepting it in unrelated prose.

Enable the optional **`r-non-nix`** companion plugin with
`nullkomma.r-non-nix.enable = true` for collaborators without Nix, then run
`write-files` and commit the resulting `.Renviron`, `.Rprofile`, `.Rbuildignore`, `.R/install.R`
and README changes.
`r-non-nix` appends an [R development without Nix](modules/lang/r-non-nix/_assets/development.md)
section to the project README, preserving existing text. These are source-of-truth
files: later upstream changes use the normal conflict-aware `write-files` updates.
This plugin imports and enables `r`; disabling `r` while enabling `r-non-nix`
is an option conflict. Both plugins are off by default. For selective imports,
use `nullkomma.flakeModules.r-non-nix` alongside `flakeModules.framework`;
no additional flake input is needed. Its startup profile leaves Nix-provided
settings and libraries untouched in development shells, builds and shared R tasks,
including parallel test workers; it requires `.Renviron` only for native R sessions.
The `r` plugin alone keeps Nix development shells, lock generation, checks and
package workflows and `.Rbuildignore`, without emitting non-Nix startup files. Snapshot and PPM settings
remain under `nullkomma.r` because `r-lock` also uses them.

Run `nix develop --command test-r-non-nix` locally on macOS or Linux with Docker
running. Nix prepares the fixture and Docker client; Docker runs Ubuntu 24.04
with the same R version as `nixpkgs-r`, as an unprivileged user, without Nix or a
mounted Nix store. Extra arguments go to `docker build`, for example
`test-r-non-nix --build-arg UBUNTU_VERSION=22.04 --build-arg R_VERSION=4.4.2`.
The test executes the documented R examples and checks an
ordinary source-package build. It uses `linux/amd64` (emulated on Apple Silicon)
to verify PPM binaries, and requires network access. Docker caches the R image
layers for subsequent runs. Sandboxed Nix checks cover startup, emitted files,
and source-package exclusions; the live Docker test also runs on manually
dispatched CI workflows, not every push.

### Files in your repo

nullkomma keeps files in your repo to a minimum; features live in Nix instead.
Some tools still need real files (Git needs `.gitignore`, GitHub needs
workflows, editors need settings). Each such file is one of two kinds:

|                             | **Source of truth** (committed, yours to edit) | **Generated from Nix** (Git-ignored, don't edit) |
| --------------------------- | ---------------------------------------------- | ------------------------------------------------ |
| `nix flake init --template` | `flake.nix`, `.envrc`                          | (not possible)                                   |
| `write-files`               | `.gitignore`, GitHub workflows                 |                                                  |
| `generate-files`            |                                                | `.vscode/*.json`, `.nvim.lua`, Quarto extensions |

Templates can't take parameters, so anything that depends on your Nix
configuration comes from `write-files` or `generate-files`.

**Source-of-truth files** (`nullkomma.files."<path>".mode = "source"`, the
default) are written once, then they are yours: edit and commit them.
When nullkomma later changes a file, `write-files` updates it only if you
haven't edited it. Otherwise it keeps your version, saves the new one next to it
and fails, pointing you to the
[resolve-file-conflicts skill](.github/skills/resolve-file-conflicts/SKILL.md).
After resolving, `write-files --accept <path>` marks the file as up to date.
A file can instead hold marked `sections` inside your own text (R's
`.Rbuildignore` rules, the `r-non-nix` README section): `write-files` replaces
only those, wherever you moved them. Once nullkomma no longer declares a file
(say, you disabled its plugin), `write-files` strips its sections, deletes it
if unedited, or keeps your edited version and says so.

### Conflict-resolution skill

The repository root is a portable [Agent Plugins 1.0 package](https://agent-plugin.org/en).
Install it from this Git repository in a compatible client. In Copilot, run:

```text
/plugin install https://github.com/dataheld/nullkomma
```

Update it with `/plugin update nullkomma`. Installing or updating the plugin
does not write to the consumer project, so its source-of-truth edits remain
untouched.

**Generated files** (`mode = "generated"`) always come from Nix.
`generate-files` overwrites them on every run, starts them with a
"do not edit" comment and the `git` plugin adds them to `.gitignore`.
To change one, change the Nix options. Directories (`directory = true`) are
copied whole, without the comment. `generate-files` refuses to overwrite a file
tracked by Git, and removes the ones it generated before that are no longer
declared.

`update` updates `flake.lock` and then runs both commands. After any other
`nix flake update` (e.g. by a bot), run `write-files` and `generate-files`
yourself.

### Editors

Editor settings live in Nix. Plugins describe their language servers once,
editor-neutrally (`perSystem.nullkomma.editor.languageServers`, including the
package that puts them in the dev shell), plus anything only one editor has
(e.g. `perSystem.nullkomma.editor.vscode.extensions`). Editor plugins (`vscode`,
`neovim`) write these out as generated, Git-ignored files, so every developer
gets support for their editor without committing editor config.
Neovim reads `.nvim.lua` only with `:set exrc` and asks once to trust it.
The editor plugins match the editors [lap](https://github.com/dataheld/lap)
sets up: VS Code and Neovim.

nullkomma only handles **project-specific** editor features: language servers,
formatters and recommended extensions. Installing editors and extensions, themes,
keybindings and personal preferences belong to your user environment, e.g.
[lap](https://github.com/dataheld/lap).

### Development Shell

After changing `flake.nix`, run `direnv reload` (or `nix-direnv-reload`) to
update your shell.

## Design

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
Each plugin's tests sit next to it in `*.test.nix`, sharing the harness in
[`modules/dev/tests.nix`](modules/dev/tests.nix). They live in the `dev`
partition, so projects using nullkomma don't inherit them.

- **Unit tests** ([nix-unit](https://github.com/nix-community/nix-unit), via the `nix` plugin) check
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

```sh
nix flake check   # unit, docs and build tests
check-fixtures    # end-to-end test
```

New plugins should add a valid and a deliberately broken fixture, and check that
the broken one fails with the real tool's error, not just any error.

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
[nix-unit]: https://github.com/nix-community/nix-unit
[nixd]: https://github.com/nix-community/nixd
[quarto]: https://quarto.org
[r]: https://www.r-project.org
[terranix]: https://terranix.org/flake-parts.html
[toml]: https://toml.io
[treefmt]: https://treefmt.com
[typos]: https://github.com/crate-ci/typos
[vscode]: https://code.visualstudio.com
[vscode-bats]: https://marketplace.visualstudio.com/items?itemName=jetmartin.bats
[vscode-quarto]: https://marketplace.visualstudio.com/items?itemName=quarto.quarto
[vscode-treefmt]: https://marketplace.visualstudio.com/items?itemName=ibecker.treefmt-vscode
[vscode-yaml]: https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml
[yaml]: https://yaml.org
[yaml-language-server]: https://github.com/redhat-developer/yaml-language-server
[`fh`]: https://github.com/DeterminateSystems/fh
[`flake-checker`]: https://github.com/DeterminateSystems/flake-checker
