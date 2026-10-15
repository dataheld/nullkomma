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
standard plugins below by default, so you only list exceptions. Website plugins
are opt-in:

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.github.enable = false;
  nullkomma.markdown.enable = false;
}
```

| Plugin                              | Dev helpers | Format / lint          | Tests               | Files                        | Editor                                                           |
| ----------------------------------- | ----------- | ---------------------- | ------------------- | ---------------------------- | ---------------------------------------------------------------- |
| [`nix`][nix]                        |             | ✅, [`flake-checker`]¹ | [nix-unit]²         | ignores `result`             | [nixd]; VS Code: [Nix IDE]                                       |
| [`markdown`][md]                    |             | ✅                     |                     |                              | [marksman]                                                       |
| [`json`][json]                      |             | ✅                     |                     |                              | [JSON language server][jsonls]                                   |
| [`yaml`][yaml]                      |             | ✅                     |                     |                              | [yaml-language-server]; VS Code: [YAML][vscode-yaml]             |
| [`toml`][toml]                      |             | ✅                     |                     |                              |                                                                  |
| [`shell`][bash]                     |             | ✅³                    | [bats]³             |                              | [bash-language-server]; VS Code: [Bash IDE], [Bats][vscode-bats] |
| [`github`][gha]                     |             | ✅                     |                     | `push.yml`⁴                  |                                                                  |
| [`keepSorted`][keep-sorted]         |             | ✅                     |                     |                              |                                                                  |
| [`typos`][typos]                    |             | ✅ spelling            |                     |                              |                                                                  |
| [`treefmt`][treefmt]                |             | runs all ✅            |                     |                              | formatter; VS Code: [treefmt][vscode-treefmt]                    |
| [`git`][git]                        | git         |                        |                     | `.gitignore`                 |                                                                  |
| [`direnv`][direnv]                  |             |                        |                     | `.envrc`, ignores `.direnv/` | VS Code: [Nix Environment Selector]                              |
| [`vscode`][vscode]                  |             |                        |                     | `.vscode/`⁵                  | renders it for VS Code⁵                                          |
| [`neovim`][neovim]                  |             |                        |                     | `.nvim.lua`⁵                 | renders it for Neovim⁵                                           |
| [`flakehub`][flakehub]              | [`fh`]      |                        |                     |                              |                                                                  |
| [`quarto`][quarto] (opt-in)         | quarto      |                        |                     | ignores `.quarto/`, `_site/` | VS Code: [Quarto][vscode-quarto]                                 |
| [`cloudflare`][cloudflare] (opt-in) |             |                        | OpenTofu validation | ignores Terraform workspace  |                                                                  |

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

The optional `quarto` and `cloudflare` plugins connect only through
`perSystem.nullkomma.site`: a package containing static assets and `index.html`,
exported as `packages.<system>.site`. Any builder or publisher can use that
framework option without enabling the other plugin.

```nix
inputs.nullkomma.lib.mkFlake { inherit inputs; } {
  nullkomma.quarto.enable = true;
  nullkomma.cloudflare = {
    enable = true;
    projectName = "helden18-github-io";
    domain = "www.helden18.de";
    zoneId = "<32-character Cloudflare zone ID>";
  };
}
```

Quarto builds the existing, user-owned `_quarto.yml` and content with
`nix build .#site`; `render` renders the current directory into its configured
output directory. Set `nullkomma.quarto.root` for another source directory, or
`perSystem.nullkomma.quarto.package` for a Quarto environment with execution
engines. The default has no R, Python or TeX. Preview process management is not
included; invoke `quarto preview` directly from the development shell.

In GitHub Actions, `nix run .#deploy` initializes OpenTofu and applies a
Workers Static Assets deployment, including the actual site files and optional
custom domain. No Worker JavaScript or Wrangler upload is needed. The provider
hashes the asset manifest during planning. `_headers` and `_redirects` are
passed as serving configuration, not published as downloadable assets.
HTML uses automatic trailing-slash handling and custom 404-page handling, not
SPA fallback. The `workers.dev` endpoint and preview URLs are disabled.
Arguments go to **OpenTofu apply**; deployment asks for approval by default.
After state adoption and plan review, CI can use
`nix run .#deploy -- -auto-approve`.

#### Terraform management and first deployment

Enabling `cloudflare` includes infrastructure management using the upstream
[Terranix flake-parts module](https://terranix.org/flake-parts.html) and OpenTofu.
The Cloudflare provider is a Nix-pinned upstream binary, not a local Go build.
`test cloudflare` and `checks.<system>.test-cloudflare` validate the actual
generated configuration offline. Customize the upstream
`perSystem.terranix.terranixConfigurations.cloudflare.modules` when necessary.

The `terraform` task and `nix run .#cloudflare.terraform -- <args>` expose
OpenTofu for imports, plans, and other operations. Set `CLOUDFLARE_ACCOUNT_ID`
and `CLOUDFLARE_API_TOKEN` at runtime, `CLOUDFLARE_STATE_BUCKET` to an
existing private R2 bucket, and its S3 credentials in `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY`. None are embedded in the build; building and checking
the site needs no credentials or state bucket. The old Pages token is not a
Workers token; use the organization secrets below instead.
State uses locking and the object key
`<projectName>.tfstate` (override `nullkomma.cloudflare.stateKey` to adopt an
existing key). Bucket provisioning and credentials belong to infrastructure
management, outside this plugin.
The workspace and its provider lock file are local and ignored; `init`
regenerates provider checksums from the Nix pin.

**All Cloudflare writes run only in GitHub Actions**, including state imports
and lock operations. `deploy` rejects execution outside Actions. The Terraform
wrapper likewise rejects local commands except `validate` and the exact offline
initialization `init -backend=false -input=false`. `test cloudflare` provides
credential-free offline validation. `GITHUB_ACTIONS=true` is an accidental-use
guard, not an authentication boundary: keep write credentials only in Actions,
never set that variable locally to bypass the guard.

##### Organization-wide GUI bootstrap

Create these in the Cloudflare account that hosts the websites. These are
account-owned service credentials, not personal tokens. A GitHub organization
does not itself scope a Cloudflare token.

1. **Manage account → Account API tokens → Create Token**: name it
   `github-actions-dataheld-workers`. Grant only **Account → Workers Scripts →
   Edit**, scoped to the hosting account. This covers asset uploads, Worker
   settings, and the custom-domain API (which manages the hostname's DNS and
   certificate). No Pages, DNS Edit, Workers Routes, or R2 administration
   permission is needed for the resources this plugin manages. Do not use
   the broader "Edit Cloudflare Workers" template unchanged.
1. **R2 object storage → Create bucket**: create a private
   `dataheld-terraform-state` bucket (or another available name), using default
   jurisdiction, not an EU/US-specific jurisdiction. Leave public access
   disabled; do not add a retention lock or lifecycle expiration for state.
1. **R2 → Overview → Account Details → Manage API tokens → Create Account API
   token**: name it `github-actions-dataheld-r2-state`. Choose **Object Read &
   Write**, **specific buckets only**, and select only the state bucket. This
   allows state/lock object reads, writes and deletion, not bucket
   administration. Record the **Access Key ID** and **Secret Access Key** shown
   once; do not substitute the general API token string for either.

Prefer an explicit expiration with a rotation reminder. Ordinary GitHub-hosted
runners do not have a fixed egress IP, so do not add an arbitrary client-IP
allowlist. Keep credentials out of local shells, Nix configuration and chat.
See Cloudflare's [account tokens][cf-account-tokens], [custom-domain API
permissions][cf-domain-api], and [R2 token instructions][cf-r2-tokens].

In **GitHub → dataheld → Settings → Secrets and variables → Actions**, create
these organization **secrets**, each available only to **selected repositories**
that actually deploy:

| Organization secret               | Value                                            |
| --------------------------------- | ------------------------------------------------ |
| `CLOUDFLARE_API_TOKEN_WORKERS`    | `github-actions-dataheld-workers` token          |
| `CLOUDFLARE_R2_ACCESS_KEY_ID`     | `github-actions-dataheld-r2-state` Access Key ID |
| `CLOUDFLARE_R2_SECRET_ACCESS_KEY` | Its Secret Access Key                            |

Create organization **variables** `CLOUDFLARE_ACCOUNT_ID` (hosting account ID)
and `CLOUDFLARE_STATE_BUCKET` (bucket name), with the same selected repositories.
Both values are non-secret. The zone ID is also non-secret and belongs in each
site's `nullkomma.cloudflare.zoneId`; find it on the domain's Overview page.
Use this job-level mapping in adoption and deployment jobs:

```yaml
env:
  CLOUDFLARE_ACCOUNT_ID: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
  CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN_WORKERS }}
  CLOUDFLARE_STATE_BUCKET: ${{ vars.CLOUDFLARE_STATE_BUCKET }}
  AWS_ACCESS_KEY_ID: ${{ secrets.CLOUDFLARE_R2_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.CLOUDFLARE_R2_SECRET_ACCESS_KEY }}
```

An existing account variable such as `CLOUDFLARE_ACCOUNT_ID_HELDEN18DE` can still
be mapped to `CLOUDFLARE_ACCOUNT_ID` instead. Shared credentials work only for
websites in the same Cloudflare account; use account-specific credential sets
otherwise. Organization secrets cannot be granted to a personal-account
repository, and GitHub Free does not expose organization secrets to private
repositories. See [GitHub organization secrets][gh-org-secrets].

**Shared credentials share their blast radius:** Workers Scripts Edit is
account-wide, not restricted to this site's Worker. Every selected repository
can also access all state objects in the shared bucket; distinct `stateKey`s
avoid collisions but are not access controls. Use separate credentials/buckets
for repositories with different trust levels.

##### Adoption and Pages cutover

Do not create the Worker in the dashboard: for a new Worker, Terraform creates
it and its assets. A Pages project is a different resource and cannot be
imported as a Worker. For helden18, keep Pages serving production until a
reviewed cutover. Deploy and inspect the Worker on a temporary custom hostname
first: leave `domain = null` and add a separate temporary
`cloudflare_workers_custom_domain.preview` through the upstream Terranix
`modules` option. Keep the same Worker name and state key throughout migration,
then configure the production `domain`/`zoneId` once that hostname is free.
Do not change a temporary `site` domain into the production domain: the
replacement would be blocked by `prevent_destroy`. Remove the separate
temporary resource only after production verification. No `workers.dev`
preview is enabled implicitly.

Workers custom domains require an active zone in the same Cloudflare account.
The production Pages custom-domain attachment and its conflicting CNAME must
be removed in a separate reviewed Actions migration before attaching that
hostname to the Worker. This may cause a brief outage; record the previous
attachment/DNS for rollback. The normal Worker token deliberately cannot
delete Pages resources or arbitrary DNS records: use separately scoped,
temporary migration credentials in a protected manual workflow, and revoke
them afterward. Do not remove Pages now or give steady-state credentials
those extra permissions. Existing Pages Terraform state requires an explicit
state migration/retirement plan, not reuse of a Pages resource address.

Only if adopting an **existing Worker**, import its resources in a dedicated
`workflow_dispatch` job on the protected default branch. After checkout and Nix
installation, run the following with the same runtime credentials as deployment.
Obtain the existing domain ID from the dashboard/API read output, not the
hostname or zone ID:

```sh
nix run .#cloudflare.terraform -- init -input=false
nix run .#cloudflare.terraform -- import cloudflare_workers_script.site "$CLOUDFLARE_ACCOUNT_ID/helden18-github-io"
nix run .#cloudflare.terraform -- import cloudflare_workers_script_subdomain.site "$CLOUDFLARE_ACCOUNT_ID/helden18-github-io"
nix run .#cloudflare.terraform -- import cloudflare_workers_custom_domain.site "$CLOUDFLARE_ACCOUNT_ID/$WORKER_DOMAIN_ID"
nix run .#cloudflare.terraform -- plan -input=false
```

Launch that job from **Actions → adoption workflow → Run workflow** in GitHub's
GUI, then review the plan before approving the first deployment. Terraform
imports cannot be performed in Cloudflare's GUI. The consumer must supply the
adoption and deployment jobs; the generic generated `push.yml` does not deploy.
Protect workflow changes and the default branch, gate the deployment job on
successful checks, and use a production environment with branch restrictions
and approval where available. Organization secrets themselves are not gated by
environment approval. Serialize adoption and deployment with the same
concurrency group and `cancel-in-progress: false`; never expose write secrets
to untrusted pull-request code.

Only import the domain if configured and already attached. New Workers/domains
are created by apply. Worker/domain destruction is guarded by `prevent_destroy`;
removing that resource's configuration also removes its lifecycle guard.
Custom-domain attachment manages its own DNS record and certificate, but the
plugin does not manage zone-wide DNS, apex redirects, email or unrelated
hostnames. The provider plans local asset changes but does not independently
verify the remote asset manifest on refresh: do not mix dashboard/Wrangler
publishing with Terraform ownership.

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
[cf-account-tokens]: https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/
[cf-domain-api]: https://developers.cloudflare.com/api/resources/workers/subresources/domains/methods/update/
[cf-r2-tokens]: https://developers.cloudflare.com/r2/api/tokens/
[cloudflare]: https://pages.cloudflare.com
[direnv]: https://direnv.net
[flakehub]: https://flakehub.com
[gh-org-secrets]: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#creating-secrets-for-an-organization
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
