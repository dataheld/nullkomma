# nullkomma ⚡️❄️

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/dataheld/nullkomma/badge)](https://flakehub.com/flake/dataheld/nullkomma)

Opinionated 🤓,
batteries-included 🔋,
extra-[DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) 🤌
[Nix](https://nixos.org) ❄️ boilerplate.

> nullkommanix [ɪn ˈnʊl ˌkɔma ˈnɪçt͡s] noun German colloquialism (translation: in next to time).

## Scope

nullkomma is **per-project** Nix scaffolding: devshells, formatters, linters, checks, tasks, docs, deploys, CI and editor settings, packaged as composable [flake-parts](https://flake.parts) modules.

It is **not**:

| Concern                                                  | Lives in                                                |
| -------------------------------------------------------- | ------------------------------------------------------- |
| Fleet placement, clan, networking, fleet secrets         | [dataheld/aoshima](https://github.com/dataheld/aoshima) |
| Host baseline (boot, disk, hardening, host services)     | [dataheld/pads](https://github.com/dataheld/pads)       |
| User environment policy (home-manager, shell ergonomics) | [dataheld/lap](https://github.com/dataheld/lap)         |
| Agentic coding app / runtime                             | [dataheld/gittens](https://github.com/dataheld/gittens) |

Separation tracker: [dataheld/aoshima#227](https://github.com/dataheld/aoshima/issues/227).

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

1. In your project, add a `flake.nix` from one of the templates (`default`, `r` or `quarto`):

   ```sh
   nix flake init --template "https://flakehub.com/f/dataheld/nullkomma/0.1.*#default"
   ```

1. Initialize missing files (`.gitignore`, `.envrc`, CI workflows, editor settings):

   ```sh
   git add flake.nix
   nix run .#write-files
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

The default aspect also exports [flake schemas](https://github.com/DeterminateSystems/flake-schemas)
for standard outputs (`packages`, `checks`, `devShells`, `apps`, etc.) and module/library outputs.
Schema-aware Nix tooling can inventory and validate these outputs; ordinary Nix can still consume the flake.
The shared `flake-schemas` input adds one lightweight node to consumer locks, with no language toolchain dependencies.

A project's entire nullkomma footprint is its `flake.nix` (and `flake.lock`):

```nix
{
  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nullkomma.flakeModules.r ];
    };
}
```

`nullkomma.lib.mkFlake` is [`flake-parts.lib.mkFlake`](https://flake.parts/getting-started) with `flakeModules.default` already imported,
so everything flake-parts can do, a nullkomma project can do, too.
The project needs no other inputs: Nixpkgs, flake-parts and treefmt-nix come pinned with nullkomma.

All tasks are self-documented:

```sh
nix run
```

Then, as usual: `nix develop`, `nix fmt`, `nix flake check`, `nix flake show`.

### Aspects

Each aspect is a flake-parts module in `flakeModules`.
Import only the ones a project needs; an aspect never adds anything to a project that does not import it.

| Aspect             | Adds                                                                                                                                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default`          | devshell, [treefmt](https://github.com/numtide/treefmt-nix) (Nix, Markdown, YAML, JSON, TOML, shell, GitHub Actions), tasks (`check`, `update`, `flake-checker`, `write-files`), initial `.gitignore`, `.envrc`, CI workflow and VS Code settings |
| `r`                | R with all packages from `DESCRIPTION`, [air](https://posit-dev.github.io/air/) (and optionally [jarl](https://jarl.etiennebacher.com)), `checks.r-cmd-check`, VS Code extensions                                                                 |
| `quarto`           | Quarto, `packages.site` (if there is a `_quarto.yml`), tasks `render` and `preview`; with `r`, R chunks run with the project's R environment                                                                                                      |
| `cloudflare-pages` | task `deploy` of `packages.site` to [Cloudflare Pages](https://pages.cloudflare.com), run by CI on pushes to the default branch                                                                                                                   |

### Knobs

Options live under `nullkomma.*`, for example (the generated [option reference](reference.qmd) lists all of them, also under `perSystem`; build it with `nix build .#docs-reference`):

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  imports = with inputs.nullkomma.flakeModules; [ r quarto cloudflare-pages ];
  nullkomma = {
    r.extraPackages = [ "devtools" ];
    cloudflare-pages.project = "my-site";
    github.ci.inputs.visibility = "public"; # publish to FlakeHub
  };
  perSystem =
    { pkgs, ... }:
    {
      nullkomma.devshell.packages = [ pkgs.hello ];
      treefmt.programs.typos.enable = true;
    };
}
```

### R dependencies and snapshots

Keep dependencies in `DESCRIPTION`, including version constraints. Select the CRAN date
in the project's ordinary `.Rprofile`, so non-Nix users can use the same setting:

```r
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/2026-01-05"))
```

nullkomma reads that setting with R and selects a pinned
[rstats-on-nix/nixpkgs](https://github.com/rstats-on-nix/nixpkgs) revision from
[`lib/r-snapshots.json`](lib/r-snapshots.json). Only listed dates are supported.
This reuses nixpkgs' source hashes, dependency graph, R build recipes and curated
system libraries; nullkomma does **not** fetch and resolve arbitrary PPM packages.
The same calendar date is not a guarantee of identical PPM and nixpkgs package sets,
nor of consistency after overrides. R checks the project's version constraints
against selected versions, failing rather than silently ignoring mismatches.

The locked nullkomma revision freezes the date-to-commit table; the snapshot is
**not an additional `flake.lock` node**. Updating nullkomma adds available dates,
but does not advance your `.Rprofile` date. Maintenance appends new dates without
changing existing pins (`python3 tools/update-r-snapshots.py`). Without a dated
profile, R follows the locked `nixpkgs-r` input (by default the main nixpkgs input).
An explicit `inputs.nullkomma.inputs.nixpkgs-r.url` remains an escape hatch when
there is no profile date.

Pinned GitHub overrides are supported in `DESCRIPTION`, for example:

```dcf
Imports: withr (>= 3.0.3.9000)
Remotes: r-lib/withr@d82e4bc2d69a34f044ad205210e26207bfb8f3e0
```

`github::owner/repo@<full-sha>` and `package=owner/repo@<full-sha>` also work.
Existing CRAN recipes retain their system-library customizations; new packages
use `rPackages.buildRPackage`. Extra system libraries can be supplied with
`perSystem = { pkgs, ... }: { nullkomma.r.buildInputs.myPackage = [ pkgs.gdal ]; };`.
Remote runtime/build dependencies and their version constraints are read from
that source's DESCRIPTION. Native build hooks may still require a custom recipe.

**Initial limits:** mutable refs are rejected, not automatically locked. Other
pak references (GitLab, URLs, subdirectories, local packages, `Config/Needs`),
transitive `Remotes`, dependency cycles and arbitrary constraint solving are not
supported. Full pak-compatible resolution and locking mutable refs remain open
work; this is not a universal DESCRIPTION resolver. GitHub source availability
is not guaranteed forever. Pure GitHub fetching was tested with Determinate Nix
3.21.9; older Nix versions may require additional source hashes.

R's `read.dcf`, `tools::package_dependencies` and version parser run inside small
derivations (import from derivation). Evaluation needs a build-capable machine
for the target system and IFD enabled, and may build both bootstrap and snapshot R.
The profile executes in an isolated build directory, not the project directory:
keep its repository setting self-contained and do not depend on other files,
network access or installed packages. Ordinary R startup still loads it normally.
`nix develop` creates a writable `R_LIBS_USER` outside the store for interactive
`install.packages()`; these installations are **not Nix-reproducible** and may
shadow pinned packages. Nix checks do not use that user library. Non-Nix users
can use ordinary R/pak tooling without adopting nullkomma.

### Initialized files

Some files must live in the repo, so `nix run .#write-files` initializes missing
`.gitignore`, `.envrc`, `.github/workflows/push.yml`, `.vscode/*.json`, and (for R) `.Rprofile` files.
The initial R profile selects the latest shipped snapshot date; existing profiles are preserved.
Configure their initial contents in `flake.nix` (e.g. `nullkomma.gitignore`, `nullkomma.editor.vscode`).
After initialization they belong to you: edit them directly. Re-running `write-files`
preserves existing files, and there is no drift check or automatic overwrite on upgrades.
Commit them; the initial `.gitignore` re-includes these paths to override a global `core.excludesFile`.
The CI stub calls nullkomma's reusable [`ci.yml`](.github/workflows/ci.yml).
The scheduled `cron.yml` maintenance workflow exists only in nullkomma itself, not in consumers.

## Updating

### Nix

There are two separate aspects to updating the nix dependencies.

1. There may be newer versions available _given_ the pinning in `flake.nix`.
   This can be accomplished by running `nix run .#update` locally and may change the `flake.lock`.
   However such updates may break a project.
   Review updates and run checks before merging. Nullkomma itself uses a scheduled
   `cron.yml` workflow to open update pull requests; downstream repos do not receive this workflow.
   Updates never overwrite your initialized repository files.
1. The versions pinned in `flake.nix` (and the resulting `flake.lock`) itself may be out of date.
   The [DeterminateSystems/flake-checker](https://github.com/DeterminateSystems/flake-checker) will fail if this is the case.
   It runs on every push as well as periodically.
   You can also run this locally using `nix run .#flake-checker`.

### Development Shell

To bring the shell you are working in up to date with the _source_
(`flake.nix`, etc.)
of your repository:

```sh
direnv reload
```

Or if you have `nix-direnv` installed,:

```sh
nix-direnv-reload
```

## Developing

nullkomma follows the [dendritic pattern](https://github.com/mightyiam/dendritic):
every `.nix` file under [`modules/`](modules) is a flake-parts module, imported automatically
(files and directories starting with `_` are skipped).
Files add to the exported aspects by defining `flake.flakeModules.<aspect>`, so one aspect can span many files
and one file can extend several aspects; [`modules/lang/quarto/r.nix`](modules/lang/quarto/r.nix), for example, wires R into Quarto only if both are imported.

nullkomma uses itself:
its devshell, formatter, checks and this website come from the `dev` [partition](https://flake.parts/options/flake-parts-partitions.html),
so development-only configuration is not evaluated by consumers.
The fixtures in [`tests/fixtures`](tests/fixtures) are evaluated like projects using nullkomma, and their checks, devshells and sites are part of `nix flake check`.

## Issues

`nix-`/`direnv` can be a bit chatty on launch.
Set [`hide_env_diff=true`](https://direnv.net/man/direnv.toml.1.html) to quiet it down.
