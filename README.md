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

   > [!TIP]
   > `nix-`/`direnv` can be a bit chatty on launch.
   > Set [`hide_env_diff=true`](https://direnv.net/man/direnv.toml.1.html) to quiet it down.

1. In your project, add a `flake.nix` from the `default` template:

   ```sh
   nix flake init --template "https://flakehub.com/f/dataheld/nullkomma/0.1.*#default"
   ```

   The template also includes `.envrc` containing `use flake`.
   Existing files are preserved.

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
arguments, e.g. `write-files --accept-shared <path>`). The
[DeterminateSystems/up](https://github.com/DeterminateSystems/up) runner lists
them and runs them without arguments:

```sh
tasks          # list tasks
tasks check    # run one task
tasks all      # run all tasks not marked `skip` (mutating tasks are skipped)
```

### Plugins and integrations

A **plugin** is a project/language/tool bundle exported as a flake-parts module
in `plugins`.
Plugins are the rows in the table below.

A plugin can contribute to several **integrations**.
Integrations are the columns in the table below,
and constitute shared configuration interfaces.

All plugins are optional. `nullkomma.lib.mkFlake` imports their definitions and
enables the usual defaults using `mkDefault`; callers only need to specify
exceptions, for example:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.github.enable = false;
  nullkomma.markdown.enable = false;
}
```


| Plugin (`plugins.<name>`) | Development environment | Formatting / linting    | Builds / checks  | Tasks / CI                         | Project files                        | Editor / LSP                                     |
| ------------------------- | ----------------------- | ----------------------- | ---------------- | ---------------------------------- | ------------------------------------ | ------------------------------------------------ |
| `nix`                     | nixd, flake-checker     | nixfmt, deadnix         | Via treefmt      | `check`, `update`, `flake-checker` | Nix build ignores                    | Nix IDE recommendation and nixd settings         |
| `markdown`                | Via treefmt             | mdformat                | Via treefmt      | None                               | None                                 | None                                             |
| `json`                    | Via treefmt             | jsonfmt                 | Via treefmt      | None                               | None                                 | None                                             |
| `yaml`                    | Via treefmt             | yamlfmt                 | Via treefmt      | None                               | None                                 | None                                             |
| `toml`                    | Via treefmt             | toml-sort               | Via treefmt      | None                               | None                                 | None                                             |
| `shell`                   | Via treefmt             | shfmt, shellcheck       | Via treefmt      | None                               | None                                 | None                                             |
| `github`                  | Via treefmt             | actionlint              | Via treefmt      | Reusable GitHub CI                 | CI stub                              | None                                             |
| `keepSorted`              | Via treefmt             | keep-sorted             | Via treefmt      | None                               | None                                 | None                                             |
| `treefmt`                 | treefmt wrapper         | Combines selected tools | Formatting check | `nix fmt`                          | None                                 | Treefmt recommendation/settings                  |
| `git`                     | Git                     | None                    | None             | None                               | Initial `.gitignore`                 | None                                             |
| `direnv`                  | User supplies direnv    | None                    | None             | Shell activation                   | `.envrc`, direnv ignores             | Nix environment selector recommendation/settings |
| `editor`                  | None                    | None                    | None             | None                               | Local VS Code files, ignore patterns | Publishes contributions from enabled plugins     |
| `flakehub`                | FlakeHub CLI (`fh`)     | None                    | None             | None                               | None                                 | None                                             |

All listed plugins are currently enabled by default..

### Knobs

Options live under `nullkomma.*`, for example:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.github.ci.inputs.visibility = "public"; # publish to FlakeHub
  perSystem =
    { pkgs, ... }:
    {
      nullkomma.devshell.packages = [ pkgs.hello ];
      treefmt.programs.typos.enable = true;
    };
}
```

### Boilerplate Files

nullkomma relies on as few "boilerplate" files in user repos as possible.
For example, the `flake.nix` file to use nullkomma itself is intentionally kept short,
and there should be no need for extra nix files or lines to add some feature (say, linting) for some project.
Instead, such features are abstracted away in the above nix modules.

There are however some exceptions to this design goal:

1. Some tooling in the interactive development environment expects local files to work properly.
   For example, `git` needs a local `.gitignore`, GitHub Actions needs a local `.github/workflows/push.yml` and editors might need local files for extensions and settings (see `.vscode/`).
1. Some languages have their own rich conventions of project files, to, for example, declare dependencies (R's `DESCRIPTION`, or python's `requirement.txt`).
   While nullkomma could abstract these away in a module and write them out as an artifact,
   we avoid doing that if the native project files are a well-established and superior API.
   (Because such project files for dependencies often allow floating references, a separate, language-specific `*.lock` file is then also added to the source.)

There are two independent questions:
**how a file is created** and **where its source of truth lives**.

| Creation                    | Shared, project-owned (commit it)                                 | Local, Nix-owned (Git-ignored)            |
| --------------------------- | ----------------------------------------------------------------- | ----------------------------------------- |
| `nix flake init --template` | Starter `flake.nix`, `.envrc`, future language starter files      |           |
| Evaluated Nix configuration | `write-files`: workflows, `.gitignore`, other shared initializers | `generate-files`: VS Code workspace files |

**Shared files** (`perSystem.nullkomma.files."<path>".mode = "shared"`, the
default) become project-owned.
Edit them and commit them.
`write-files` remembers the last upstream initializer as a baseline in local Git metadata.
It updates a file automatically only if it still matches that baseline (or already matches
the new initializer).
When upstream changes and the project file differs,
it preserves the project file, saves an incoming candidate and exits unsuccessfully
with instructions for the [resolve-file-conflicts skill](.github/skills/resolve-file-conflicts/SKILL.md).

Unrelated project edits are not conflicts when upstream is unchanged.
An existing, different file without a baseline also requires review; a new clone
does not have the previous clone's local baseline.

**Generated files** (`mode = "generated"`) remain Nix-owned.
Do not edit them:
change the Nix options instead.
`generate-files` writes an ownership warning
using the file's declared `commentPrefix` (`//` for VS Code's JSONC), makes the
local copy read-only, and adds
root-relative patterns to `.git/info/exclude`, independently of the Git plugin.
It prompts before replacing different existing content; `--yes` explicitly
authorizes unattended replacement. Noninteractive runs without consent fail
rather than silently skip stale files. Tracked files and symlink targets are
rejected; migration requires deliberately moving useful edits into Nix and
untracking the file. Strict formats without comment support must not use this
mode until an appropriate warning representation is designed.

VS Code files default to generated mode; workflows and `.gitignore` default to
shared mode. Git ignore status alone never grants overwrite permission.
Builds must consume store-backed sources, not ignored workspace copies.
Disabled/removed files are not deleted automatically.

`update` updates the lock file, then re-evaluates both file commands
against the updated flake, reporting conflicts and requesting replacement
consent. After a direct `nix flake update`, a bot update or pulling a changed lock
file, run `write-files` and `generate-files` yourself: Nix provides no universal
post-update hook. Baselines and local excludes are not committed; review shared
file changes normally.

### Editor ownership

nullkomma owns **project-specific** editor features: formatter and language-server commands,
workspace paths, and recommendations for extensions needed by the imported plugins.
[lap](https://github.com/dataheld/lap) owns VS Code installation, extension installation,
themes, keybindings, and personal preferences. `extensions.json` recommends extensions;
it does not install them.

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

## Design

### Neutral interfaces between plugins

Plugins connect through **shared contracts, not each other's implementation**.

The framework owns these contracts; producers supply values and consumers use
them without inspecting which plugin supplied them.
Keep interfaces neutral with
respect to language, build tool, CI provider and deployment destination.

For example, `perSystem.nullkomma.site` is a static-site derivation whose output
root contains `index.html`, exported as `packages.<system>.site`.
A future Quarto
plugin can supply it; a future Cloudflare deployment plugin can consume it.
Neither should require the other: another site producer or deployment destination
must be substitutable when it satisfies the same contract.
These are architectural examples, not currently implemented plugins.

## Development

### Testing nullkomma

Tests of nullkomma itself live in the development partition; consumers do not
inherit them. Use three complementary layers:

- **Module contracts:** `lib.debug.runTests` checks evaluated consumer options,
  overrides, templates and exported outputs.
- **Build contracts:** consumer fixture checks are included in nullkomma's own
  `checks`. Inspect successful build outputs as well as build success. For negative
  fixtures, use Nixpkgs' `testers.testBuildFailure'` with an expected exit code and
  tool-specific log entries; an arbitrary failure is not sufficient.
- **CLI integration:** `nix develop --command check-fixtures` runs real `nix flake check`
  commands against good and bad consumer input, overriding nullkomma with this
  checkout. This tests input resolution and CLI failure propagation, which the
  in-process fixture evaluator does not cover. nullkomma's own CI runs it before
  the reusable build/publish workflow.

Each formatter/linter plugin adds one invalid file to `rejects` in
`modules/dev/tests.nix`; both the build contract (`formatting-rejects-<plugin>`)
and the CLI integration test assert that it fails with that tool's diff, while the
valid fixture passes.

Run the build contracts with `nix flake check`. CLI integration runs outside
derivation builders: no nested Nix daemon, recursive builds or import-from-derivation
is needed. Fixtures use the checkout's locked dependencies, not the published
nullkomma release.

New language plugins should add small successful and deliberately broken fixtures.
The successful fixture must exercise the actual build and verify meaningful output;
the broken fixture must fail at the intended stage with its expected diagnostic.
Do not compare an output with itself or substitute a dummy failing builder for the
real tool. Keep invalid fixture content out of the repository-wide formatter's
input, for example by constructing it with `pkgs.writeTextDir`.

These patterns follow [flake-parts' module tests](https://github.com/hercules-ci/flake-parts/blob/main/dev/tests/nix-unit.nix),
[treefmt-nix's consumer integration tests](https://github.com/numtide/treefmt-nix/blob/main/run-tests.sh),
and [Nixpkgs' testing helpers](https://nixos.org/manual/nixpkgs/unstable/#chap-testers).
`runTests` suffices for current value comparisons; consider
[nix-unit](https://github.com/nix-community/nix-unit) when precise expected
evaluation-error tests or per-test error isolation are needed.

## Updating

### Nix

There are two separate aspects to updating the nix dependencies.

1. There may be newer versions available _given_ the pinning in `flake.nix`.
   This can be accomplished by running `update` locally and may change the `flake.lock`.
   However such updates may break a project.
1. The versions pinned in `flake.nix` (and the resulting `flake.lock`) itself may be out of date.
   The [DeterminateSystems/flake-checker](https://github.com/DeterminateSystems/flake-checker) will fail if this is the case.
   It runs on every push as well as periodically.
   You can also run this locally using `flake-checker`.
