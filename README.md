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

| Plugin                              | Dev helpers | Format / lint          | Tests               | Files                            | Editor                                                           |
| ----------------------------------- | ----------- | ---------------------- | ------------------- | -------------------------------- | ---------------------------------------------------------------- |
| [`nix`][nix]                        |             | ✅, [`flake-checker`]¹ | [nix-unit]²         | ignores `result`                 | [nixd]; VS Code: [Nix IDE]                                       |
| [`markdown`][md]                    |             | ✅                     |                     |                                  | [marksman]                                                       |
| [`json`][json]                      |             | ✅                     |                     |                                  | [JSON language server][jsonls]                                   |
| [`yaml`][yaml]                      |             | ✅                     |                     |                                  | [yaml-language-server]; VS Code: [YAML][vscode-yaml]             |
| [`toml`][toml]                      |             | ✅                     |                     |                                  |                                                                  |
| [`shell`][bash]                     |             | ✅³                    | [bats]³             |                                  | [bash-language-server]; VS Code: [Bash IDE], [Bats][vscode-bats] |
| [`github`][gha]                     |             | ✅                     |                     | `push.yml`⁴                      |                                                                  |
| [`keepSorted`][keep-sorted]         |             | ✅                     |                     |                                  |                                                                  |
| [`typos`][typos]                    |             | ✅ spelling            |                     |                                  |                                                                  |
| [`treefmt`][treefmt]                |             | runs all ✅            |                     |                                  | formatter; VS Code: [treefmt][vscode-treefmt]                    |
| [`git`][git]                        | git         |                        |                     | `.gitignore`                     |                                                                  |
| [`direnv`][direnv]                  |             |                        |                     | `.envrc`, ignores `.direnv/`     | VS Code: [Nix Environment Selector]                              |
| [`vscode`][vscode]                  |             |                        |                     | `.vscode/`⁵                      | renders it for VS Code⁵                                          |
| [`neovim`][neovim]                  |             |                        |                     | `.nvim.lua`⁵                     | renders it for Neovim⁵                                           |
| [`flakehub`][flakehub]              | [`fh`]      |                        |                     |                                  |                                                                  |
| [`quarto`][quarto] (opt-in)         | quarto⁷     |                        |                     | ignores `.quarto/`, `_site/`     | VS Code: [Quarto][vscode-quarto]                                 |
| [`cloudflare`][cloudflare] (opt-in) | wrangler⁶   |                        | OpenTofu validation | ignores `.nullkomma/cloudflare/` |                                                                  |

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

⁶ Also adds the `terraform` (plan changes) and `deploy` tasks.

⁷ Also adds the `preview` task: `quarto preview`, serving the site on localhost
and re-rendering and live-reloading it on changes.

✅ means the plugin's files are formatted/linted by the `format` task (or `nix fmt`) and
checked by `nix flake check` (via treefmt). The exact tools are in the plugin's source.

Every test runs locally with `test` (or `test <name> [args]`) and, sandboxed
against the flake's source, as `checks.<system>.test-<name>` in
`nix flake check` and CI.

Each column is a framework: options (in `perSystem`, except `nullkomma.gitignore`)
that plugins fill in, and so can you. Most plugins feed columns; a few render
them (`git`, `vscode`, `neovim`) or run them (`treefmt`). Plugins never read
each other's options, only the frameworks'.

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

### Files in your repo

nullkomma keeps files in your repo to a minimum; features live in Nix instead.
Some tools still need real files (Git needs `.gitignore`, GitHub needs
workflows, editors need settings). Each such file is one of two kinds:

|                             | **Source of truth** (committed, yours to edit) | **Generated from Nix** (Git-ignored, don't edit) |
| --------------------------- | ---------------------------------------------- | ------------------------------------------------ |
| `nix flake init --template` | `flake.nix`, `.envrc`                          | (not possible)                                   |
| `write-files`               | `.gitignore`, GitHub workflows                 |                                                  |
| `generate-files`            |                                                | `.vscode/*.json`, `.nvim.lua`                    |

Templates can't take parameters, so anything that depends on your Nix
configuration comes from `write-files` or `generate-files`.

**Source-of-truth files** (`nullkomma.files."<path>".mode = "source"`, the
default) are written once, then they are yours: edit and commit them.
When nullkomma later changes a file, `write-files` updates it only if you
haven't edited it. Otherwise it keeps your version, saves the new one next to it
and fails, pointing you to the
[resolve-file-conflicts skill](.github/skills/resolve-file-conflicts/SKILL.md).
After resolving, `write-files --accept <path>` marks the file as up to date.

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
To change one, change the Nix options.

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

Plugins never read each other's options. Values shared between plugins are
framework options that any plugin may set or read. For example, `treefmt` sets
`nullkomma.editor.formatter` and the `nix` language server uses it, without
knowing which plugin set it. Another formatter plugin can replace `treefmt`
without changing `nix`.

## Development

Before building something, check [flake.parts](https://flake.parts) for an
existing module; see [AGENTS.md](AGENTS.md). Inputs only nullkomma's own
development needs go in [`dev/flake.nix`](dev/flake.nix), so they stay out of
projects' `flake.lock`.

### Testing nullkomma

nullkomma is tested against small example projects ("fixtures") in
`tests/fixtures`, which use nullkomma the way a real project would.
All tests are in [`modules/dev/tests.nix`](modules/dev/tests.nix); projects using
nullkomma don't inherit them.

- **Unit tests** ([nix-unit](https://github.com/nix-community/nix-unit), via the `nix` plugin) check
  the evaluated configuration of the fixtures, e.g. that every plugin can be
  switched off and that all off leaves just the framework.
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
