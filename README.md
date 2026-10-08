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

1. Write the generated files (`.gitignore`, `.envrc`, CI workflows, editor settings):

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

| Aspect             | Adds                                                                                                                                                                                                                                                                 |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default`          | devshell, [treefmt](https://github.com/numtide/treefmt-nix) (Nix, Markdown, YAML, JSON, TOML, shell, GitHub Actions), tasks (`check`, `update`, `flake-checker`, `write-files`), generated `.gitignore`, `.envrc`, CI workflows and VS Code settings, `checks.files` |
| `r`                | R with all packages from `DESCRIPTION`, [air](https://posit-dev.github.io/air/) (and optionally [jarl](https://jarl.etiennebacher.com)), `checks.r-cmd-check`, VS Code extensions                                                                                    |
| `quarto`           | Quarto, `packages.site` (if there is a `_quarto.yml`), tasks `render` and `preview`; with `r`, R chunks run with the project's R environment                                                                                                                         |
| `cloudflare-pages` | task `deploy` of `packages.site` to [Cloudflare Pages](https://pages.cloudflare.com), run by CI on pushes to the default branch                                                                                                                                      |

### Knobs

Options live under `nullkomma.*` (see the `options.nix` and other files in [`modules/`](modules)), for example:

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

To pin R and CRAN to a date, point nullkomma's `nixpkgs-r` input elsewhere
(this adds one node to `flake.lock`):

```nix
inputs.nullkomma.inputs.nixpkgs-r.url = "github:rstats-on-nix/nixpkgs/2026-01-05";
```

### Generated files

Some files must live in the repo, so nullkomma generates them:
`.gitignore`, `.envrc`, `.github/workflows/{push,cron}.yml` and `.vscode/*.json`.
Configure them in `flake.nix` (e.g. `nullkomma.gitignore`, `nullkomma.editor.vscode`),
then run `nix run .#write-files`; `checks.files` fails if they are out of date.
Commit them: flakes only see git-tracked files, so the generated `.gitignore` re-includes them, overriding a global `core.excludesFile`.
The workflows are thin stubs that call nullkomma's reusable [`ci.yml`](.github/workflows/ci.yml) and [`maintenance.yml`](.github/workflows/maintenance.yml).

## Updating

### Nix

There are two separate aspects to updating the nix dependencies.

1. There may be newer versions available _given_ the pinning in `flake.nix`.
   This can be accomplished by running `nix run .#update` locally and may change the `flake.lock`.
   However such updates may break a project.
   It is therefore recommended **to only run this in CI**,
   using the periodically scheduled `cron.yml` workflow.
   It will automatically open pull requests if there are updates available.
   Users can then inspect whether the updated project still passes all tests.
   If a new nullkomma generates different files, `checks.files` fails until you run `nix run .#write-files`.
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
whose extra inputs live in [`dev/flake.nix`](dev/flake.nix) and never end up in a project's `flake.lock`.
The fixtures in [`tests/fixtures`](tests/fixtures) are evaluated like projects using nullkomma, and their checks, devshells and sites are part of `nix flake check`.

## Issues

`nix-`/`direnv` can be a bit chatty on launch.
Set [`hide_env_diff=true`](https://direnv.net/man/direnv.toml.1.html) to quiet it down.
