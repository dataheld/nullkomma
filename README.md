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

1. In your project, add a `flake.nix` from the `default` template:

   ```sh
   nix flake init --template "https://flakehub.com/f/dataheld/nullkomma/0.1.*#default"
   ```

   The template also includes `.envrc` containing `use flake`.
   Existing files are preserved.

1. Initialize remaining missing files (see below):

   ```sh
   git add flake.nix .envrc
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

All tasks are self-documented:

```sh
nix run
```

Then, as usual: `nix develop`, `nix fmt`, `nix flake check`, `nix flake show`.

### Plugins and integrations

A **plugin** is a project/language/tool bundle exported as a flake-parts module
in `plugins`. A plugin can contribute to several **integrations**: the
columns below. These are shared configuration interfaces, not separate imports
or feature switches.

All plugins are optional. `nullkomma.lib.mkFlake` imports their definitions and
enables the usual defaults using `mkDefault`; callers only need to specify
exceptions, for example:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.github.enable = false;
  nullkomma.markdown.enable = false;
}
```

Disabling GitHub removes its workflow initialization **and** actionlint default.
Disabling Markdown removes its mdformat default. Explicit treefmt overrides
remain available if you want a tool without its plugin.
`lib.defaultPlugins` lists the defaults; newly exported plugins are not
automatically added to that policy. Plugins are Nix modules, not runtime plugins
or automatically discovered project types.

| Plugin (`plugins.<name>`) | Development environment | Formatting / linting    | Builds / checks  | Tasks / CI                         | Project files            | Editor / LSP                                     |
| ------------------------- | ----------------------- | ----------------------- | ---------------- | ---------------------------------- | ------------------------ | ------------------------------------------------ |
| `nix`                     | nixd, flake-checker     | nixfmt, deadnix         | Via treefmt      | `check`, `update`, `flake-checker` | Nix build ignores        | Nix IDE recommendation and nixd settings         |
| `markdown`                | Via treefmt             | mdformat                | Via treefmt      | None                               | None                     | None                                             |
| `json`                    | Via treefmt             | jsonfmt                 | Via treefmt      | None                               | None                     | None                                             |
| `yaml`                    | Via treefmt             | yamlfmt                 | Via treefmt      | None                               | None                     | None                                             |
| `toml`                    | Via treefmt             | toml-sort               | Via treefmt      | None                               | None                     | None                                             |
| `shell`                   | Via treefmt             | shfmt, shellcheck       | Via treefmt      | None                               | None                     | None                                             |
| `github`                  | Via treefmt             | actionlint              | Via treefmt      | Reusable GitHub CI                 | CI stub                  | None                                             |
| `keepSorted`              | Via treefmt             | keep-sorted             | Via treefmt      | None                               | None                     | None                                             |
| `treefmt`                 | treefmt wrapper         | Combines selected tools | Formatting check | `nix fmt`                          | None                     | Treefmt recommendation/settings                  |
| `git`                     | Git                     | None                    | None             | None                               | Initial `.gitignore`     | None                                             |
| `direnv`                  | User supplies direnv    | None                    | None             | Shell activation                   | `.envrc`, direnv ignores | Nix environment selector recommendation/settings |
| `editor`                  | None                    | None                    | None             | None                               | VS Code files            | Publishes contributions from enabled plugins     |
| `flakehub`                | FlakeHub CLI (`fh`)     | None                    | None             | None                               | None                     | None                                             |

Each cell describes that plugin's contributions, not everything inherited from
other enabled plugins. All listed plugins are currently enabled by default.
Editor contributions require `nullkomma.editor.enable`; formatter tools reach
the shell and checks through the treefmt plugin.

The separate `framework` module supplies shared options and output construction,
not tool choices. `lib.mkFlake` also enables the project devshell by default;
disable its output with `nullkomma.devshell.enable = false`.
For explicit assembly without default selection, use flake-parts directly,
import `nullkomma.framework` and the desired plugin definitions, and enable their
options. Importing a definition alone does not enable it.

This describes defaults, not every possible consumer override:

- The template supplies `.envrc`; `write-files` can initialize it and the other
  selected files if missing. Opting out does not delete files already copied by
  a template or initialized earlier. Existing files remain user-owned (see [Boilerplate Files](#boilerplate-files)).
- Extensions are recommended, not installed (see [Editor ownership](#editor-ownership)).
- CI runs checks and builds exposed packages/devshells. FlakeHub publishing is
  opt-in via `nullkomma.github.ci.inputs.visibility`.
- The generic `nullkomma.site` interface does not render a site by itself:
  `packages.site` exists only when a module supplies a site.

The columns map directly to the implementation:

- **Development environment:** [`perSystem.nullkomma.devshell`](modules/core/devshell.nix) contributes to `devShells.<system>.default`.
- **Formatting / linting:** [`perSystem.treefmt`](modules/core/treefmt.nix) supplies `formatter.<system>` and `checks.<system>.treefmt`.
- **Builds / checks:** flake-parts' `perSystem.packages` and `perSystem.checks`; [`perSystem.nullkomma.site`](modules/core/site.nix) can supply `packages.<system>.site`.
- **Tasks / CI:** [`perSystem.nullkomma.tasks`](modules/core/tasks.nix) supplies `apps.<system>`; [`nullkomma.github`](modules/tools/github.nix) configures the [reusable CI](.github/workflows/ci.yml).
- **Project files:** [`perSystem.nullkomma.files`](modules/core/files.nix), [`nullkomma.gitignore`](modules/core/gitignore.nix) and [template contents](templates/default).
- **Editor / LSP:** [`nullkomma.editor.vscode`](modules/core/editor.nix) supplies project settings, extension recommendations and `editor.vscode`; the devshell supplies server executables.

Modules compose these contributions through Nix option merging; no separate
matrix framework is involved. Explicit integrations and tests are still needed
where project types interact. nullkomma's internal development tests are not
consumer integrations.

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

If these files are not parametrised, they will be come via `nix flake init --template` (see above).

If they depend on some input from you, they will be added after the flake via `nix run .#write-files`.

After initialization, these files belong to you: edit them directly.
Re-running `write-files` preserves existing files, and there is no drift check or automatic overwrite on upgrades.
Commit them; the initial `.gitignore` re-includes these paths to override a global `core.excludesFile`.

### Editor ownership

nullkomma owns **project-specific** editor features: formatter and language-server commands,
workspace paths, and recommendations for extensions needed by the imported plugins.
[lap](https://github.com/dataheld/lap) owns VS Code installation, extension installation,
themes, keybindings, and personal preferences. `extensions.json` recommends extensions;
it does not install them.

## Testing nullkomma

Tests of nullkomma itself live in the development partition; consumers do not
inherit them. Use three complementary layers:

- **Module contracts:** `lib.debug.runTests` checks evaluated consumer options,
  overrides, templates and exported outputs.
- **Build contracts:** consumer fixture checks are included in nullkomma's own
  `checks`. Inspect successful build outputs as well as build success. For negative
  fixtures, use Nixpkgs' `testers.testBuildFailure'` with an expected exit code and
  tool-specific log entries; an arbitrary failure is not sufficient.
- **CLI integration:** `nix run .#check-fixtures` runs real `nix flake check`
  commands against good and bad consumer input, overriding nullkomma with this
  checkout. This tests input resolution and CLI failure propagation, which the
  in-process fixture evaluator does not cover. nullkomma's own CI runs it before
  the reusable build/publish workflow.

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
   This can be accomplished by running `nix run .#update` locally and may change the `flake.lock`.
   However such updates may break a project.
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

## Issues

`nix-`/`direnv` can be a bit chatty on launch.
Set [`hide_env_diff=true`](https://direnv.net/man/direnv.toml.1.html) to quiet it down.
