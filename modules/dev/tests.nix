# Contract test harness: fixtures and templates are evaluated as consumers would.
# Plugins' co-located `*.test.nix` files get it as the `harness` perSystem argument;
# fixtures' own checks and devshells become checks of nullkomma.
{
  partitions.dev.module =
    { inputs, lib, ... }:
    let
      nullkomma = inputs.self;
      root = ../..;
      plugins = removeAttrs nullkomma.flakeModules [
        "default"
        "framework"
      ];
      # Evaluates a consumer flake against this checkout, extended by `module`.
      callFlakeWith =
        module: src:
        let
          flake = import (src + "/flake.nix");
          debugged = nullkomma // {
            lib = nullkomma.lib // {
              mkFlake =
                args: consumer:
                nullkomma.lib.mkFlake args {
                  imports = [
                    consumer
                    module
                  ];
                  config.debug = true;
                };
            };
          };
          flakeInputs = {
            self = self';
            nullkomma = debugged;
            inherit (nullkomma.inputs) nixpkgs;
          };
          outputs = flake.outputs flakeInputs;
          self' = outputs // {
            _type = "flake";
            outPath = src;
            sourceInfo.outPath = src;
            inputs = flakeInputs;
            inherit outputs;
          };
        in
        self';
      callFlake = callFlakeWith { };
      # Only the framework and `module`, without default plugins.
      rawAt =
        src: module:
        inputs.flake-parts.lib.mkFlake { inputs.self.outPath = src; } {
          imports = [
            nullkomma.flakeModules.framework
            module
          ];
          debug = true;
        };
      fixtures = lib.genAttrs [
        "cloudflare"
        "md"
        "python"
        "quarto"
        "quarto-branded"
        "r"
        "r-off-nixpkgs"
        "r-shiny"
        "shell"
      ] (name: callFlake (root + "/tests/fixtures/${name}"));
    in
    {
      perSystem =
        { pkgs, system, ... }:
        let
          perSystem = flake: flake.allSystems.${system};
          # Command running a flake's task, from inside a Git repository.
          task = flake: name: "${lib.getExe (perSystem flake).taskRunners.default} ${name}";
          # Shell prelude: a writable copy of `src` as the working Git repository,
          # `fails <message> <command...>`, expecting the command to fail with message, and
          # `awaiting <condition> [pid]`, evaluating the condition until it holds; it fails
          # after 600 s, or once process `pid` has exited, showing the ends of the files in `logs`.
          project = src: ''
            cp -R ${src} project
            chmod -R u+w project
            cd project
            ${lib.getExe pkgs.git} init -q
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            fails() {
              message="$1"
              shift
              if "$@" > "$TMPDIR/failure.log" 2>&1; then
                echo "Expected failure: $message" >&2
                exit 1
              fi
              grep -qF -- "$message" "$TMPDIR/failure.log" || { cat "$TMPDIR/failure.log"; exit 1; }
            }
            logs=()
            awaiting() {
              local start=$SECONDS failure=
              until eval "$1"; do
                if [ -n "''${2-}" ] && ! kill -0 "$2" 2>/dev/null; then
                  failure="process $2 exited while"
                elif ((SECONDS - start >= 600)); then
                  failure="gave up after 600 s"
                fi
                if [ -n "$failure" ]; then
                  ((''${#logs[@]} == 0)) || tail -n 40 "''${logs[@]}" >&2 || true
                  echo "$failure waiting for: $1" >&2
                  exit 1
                fi
                sleep 0.2
              done
            }
          '';
          # What a fixture's user sees: the `nk` menu; variants of another fixture share its menu.
          snapshots =
            lib.mapAttrs
              (
                name: flake:
                pkgs.runCommand "nullkomma-snapshot-${name}" { } ''
                  ${project (root + "/tests/fixtures/${name}")}
                  {
                    printf '# `nk` in `tests/fixtures/%s`\n\n```text\n' ${name}
                    ${task flake ""}
                    printf '```\n'
                  } > "$out"
                ''
              )
              (
                removeAttrs fixtures [
                  "quarto-branded"
                  "r-off-nixpkgs"
                ]
              );
        in
        {
          legacyPackages = { inherit snapshots; };
          _module.args.harness = {
            inherit
              nullkomma
              root
              plugins
              callFlakeWith
              callFlake
              rawAt
              fixtures
              perSystem
              task
              project
              ;
            raw = rawAt (root + "/tests/fixtures/md");
            # A built site's local links and fragments resolve.
            linkcheck =
              name: site:
              # lychee builds an HTTP client even offline, which needs CA certificates on Linux.
              pkgs.runCommand "nullkomma-${name}"
                { SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"; }
                ''
                  ${lib.getExe pkgs.lychee} --offline --include-fragments --no-progress '${site}/**/*.html'
                  touch $out
                '';
            # The brand nullkomma publishes with, for fixtures checking real content.
            brand = inputs.brand;
            # After `project`: runs `process-compose up <process>` of `flake` with watches, as `$server`,
            # with shell function `settled <process> <runs>`, waiting for that many runs to exit, and no further start.
            watching = flake: process: ''
              export PC_LOG_FILE="$TMPDIR/process-compose.log"
              logs=("$TMPDIR/up.log" "$PC_LOG_FILE")
              count() { grep -E "process=$1\$" "$PC_LOG_FILE" 2>/dev/null | grep -cF " $2 " || true; }
              exited() { [ "$(count "$1" Exited)" -ge "$2" ]; }
              settled() {
                awaiting "exited $1 $2" "$server"
                sleep 3
                [ "$(count "$1" Started)" -eq "$2" ] || {
                  cat "$TMPDIR/up.log" "$PC_LOG_FILE" >&2
                  echo "Expected $2 runs of $1, got $(count "$1" Started)" >&2
                  exit 1
                }
              }
              # A stopped process signals its whole process group, so the builder needs its own.
              set -m
              NO_COLOR=1 ${lib.getExe (perSystem flake).process-compose.dev.outputs.package} up ${process} -t=false > "$TMPDIR/up.log" 2>&1 &
              server=$!
              trap 'kill "$server" 2>/dev/null || true; wait || true' EXIT
            '';
            # A build that runs servers on localhost through process-compose,
            # which finds ports with lsof on macOS, which has it outside the sandbox.
            serving =
              name: tools:
              pkgs.runCommand name {
                nativeBuildInputs = tools ++ [ pkgs.lsof ];
                __darwinAllowLocalNetworking = true;
              };
            # Every page of a built site meets German legal requirements.
            legalcheck =
              name: site:
              pkgs.runCommand "nullkomma-${name}" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
                cd ${site}
                pandoc lua ${./_legal.lua} "$PWD" $(find . -name '*.html' -printf '%P\n')
                touch $out
              '';
            # What plugins can contribute to a consumer flake.
            summary = flake: {
              files = lib.attrNames (perSystem flake).nullkomma.files;
              tools = map lib.getName (perSystem flake).nullkomma.devShell.packages;
              formatters = lib.attrNames (perSystem flake).treefmt.build.programs;
              tasks = lib.attrNames (perSystem flake).taskRunners.default.tasks;
              checks = lib.attrNames flake.checks.${system};
              shells = lib.attrNames flake.devShells.${system};
              editor =
                let
                  inherit ((perSystem flake).nullkomma) editor;
                in
                {
                  formatter = if editor.formatter == null then null else editor.formatter.command;
                  languageServers = lib.mapAttrs (_: s: removeAttrs s [ "package" ]) editor.languageServers;
                  inherit (editor) vscode;
                };
            };
            # After `project`: shell functions `format [files]` and `rejects <message> [files]` with `flake`'s treefmt.
            treefmt = flake: ''
              format() {
                ${lib.getExe (perSystem flake).treefmt.build.wrapper} --no-cache --walk=filesystem "$@"
              }
              rejects() {
                rule="$1"
                shift
                fails "$rule" format "$@"
              }
            '';
          };
          # Sandboxed: nix-unit re-evaluates this flake with its inputs passed in.
          nullkomma.nix.unit.allowNetwork = true;
          # Terranix's non-followed inputs also need paths in nix-unit's fresh store.
          nullkomma.nix.unit.inputs =
            lib.mapAttrs (_: input: input.outPath) (
              removeAttrs inputs [
                "self"
                "brand"
              ]
            )
            // {
              "terranix/import-tree" = inputs.terranix.inputs.import-tree.outPath;
              "terranix/systems" = inputs.terranix.inputs.systems.outPath;
            };
          process-compose.dev.settings.processes.build-fixture-interactive = {
            description = "Build a fixture for interactive use: a new Git repository using this checkout, set up as README's Getting started does";
            disabled = true;
            command = pkgs.writeShellApplication {
              name = "build-fixture-interactive";
              runtimeInputs = [
                pkgs.direnv
                pkgs.git
                pkgs.gnused
              ];
              text = ''
                root="$(git rev-parse --show-toplevel)"
                case "''${1-}" in
                  ${lib.concatStringsSep "|" (lib.attrNames fixtures)}) ;;
                  *)
                    echo "Usage: nk build-fixture-interactive <${lib.concatStringsSep "|" (lib.attrNames fixtures)}>" >&2
                    exit 1
                    ;;
                esac
                # Not $TMPDIR: `nix develop` deletes its own when it exits.
                scratch="$(mktemp -d "/tmp/nk-$1.XXXXXX")"
                cp -R "$root/tests/fixtures/$1/." "$scratch"
                sed -i "s|nullkomma.url = .*|nullkomma.url = \"git+file://$root\";|" "$scratch/flake.nix"
                cd "$scratch"
                git init -q
                git add -A
                nix develop --command nk write-files
                nix develop --command nk generate-files
                git add -A
                git commit -qm "add nullkomma"
                direnv allow
                echo "cd $scratch"
              '';
            };
          };
          process-compose.dev.settings.processes.update-snapshots = {
            description = "Rewrite tests/snapshots from the fixtures; review the snapshot checks' diffs first";
            disabled = true;
            command = pkgs.writeShellApplication {
              name = "update-snapshots";
              text = lib.concatMapStrings (name: ''
                install -m 644 "$(nix build --no-link --print-out-paths .#legacyPackages.${system}.snapshots.${name})" tests/snapshots/${name}.md
              '') (lib.attrNames snapshots);
            };
          };
          process-compose.dev.settings.processes.all.depends_on.check-fixtures.condition =
            "process_completed_successfully";
          process-compose.dev.settings.processes.check-fixtures = {
            description = "Run nix flake check and flake-checker on a fixture project, and initialize the template";
            disabled = true;
            command = pkgs.writeShellApplication {
              name = "check-fixtures";
              runtimeInputs = [
                pkgs.flake-checker
                pkgs.git
              ];
              text = ''
                root="$(git rev-parse --show-toplevel)"
                scratch="$(mktemp -d)"
                trap 'rm -rf "$scratch"' EXIT
                # The root needs no partition for what it defines itself; `dev/` is missing here.
                mkdir "$scratch/root" "$scratch/init"
                cp -R "$root"/{flake.nix,flake.lock,lib,modules,templates} "$scratch/root/"
                (cd "$scratch/init" && nix flake init --template "path:$scratch/root")
                mkdir "$scratch/project"
                cp "$root/tests/fixtures/md/flake.nix" "$root/tests/fixtures/md/README.md" "$scratch/project/"
                nix flake check "path:$scratch/project" \
                  --override-input nullkomma "path:$root" \
                  --no-write-lock-file --print-build-logs
                # Consumer CI lints the lock; its Nixpkgs must be visible as a root input.
                nix flake lock "path:$scratch/project" --override-input nullkomma "path:$root"
                flake-checker --no-telemetry --fail-mode "$scratch/project/flake.lock"
              '';
            };
          };
          checks =
            lib.concatMapAttrs (
              name: flake:
              lib.mapAttrs' (check: lib.nameValuePair "fixture-${name}-${check}") (
                flake.checks.${system} // { devshell = flake.devShells.${system}.default; }
              )
            ) fixtures
            // lib.mapAttrs' (
              name: snapshot:
              lib.nameValuePair "snapshot-${name}" (
                pkgs.runCommand "nullkomma-snapshot-${name}-check" { } ''
                  diff -u ${root + "/tests/snapshots/${name}.md"} ${snapshot} || {
                    echo "tests/snapshots/${name}.md is stale; review the diff, then run nk update-snapshots." >&2
                    exit 1
                  }
                  touch "$out"
                ''
              )
            ) snapshots;
        };
    };
}
