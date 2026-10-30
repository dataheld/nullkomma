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
                  debug = true;
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
        "quarto"
        "quarto-branded"
        "r"
        "r-remotes"
        "shell"
      ] (name: callFlake (root + "/tests/fixtures/${name}"));
      # One invalid file per formatter, checked by both the derivation and the real CLI.
      rejects = {
        nix = {
          file = "unformatted.nix";
          content = "{foo=1;}\n";
          expect = [
            "diff --git a/unformatted.nix b/unformatted.nix"
            "+{ foo = 1; }"
          ];
        };
        markdown = {
          file = "unformatted.md";
          content = "# Title\n* item\n";
          expect = [
            "diff --git a/unformatted.md b/unformatted.md"
            "+- item"
          ];
        };
      };
    in
    {
      perSystem =
        { pkgs, system, ... }:
        let
          perSystem = flake: flake.allSystems.${system};
          # Command running a flake's task, from inside a Git repository.
          task = flake: name: "${lib.getExe (perSystem flake).taskRunners.default} ${name}";
          # Shell prelude: a writable copy of `src` as the working Git repository, and
          # `fails <message> <command...>`, expecting the command to fail with message.
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
          '';
          # What a fixture's user sees: the `nk` menu and the task graph.
          snapshots = lib.mapAttrs (
            name: flake:
            pkgs.runCommand "nullkomma-snapshot-${name}" { } ''
              ${project (root + "/tests/fixtures/${name}")}
              export PC_LOG_FILE="$TMPDIR/pc.log"
              {
                printf '# `nk` in `tests/fixtures/%s`\n\n```text\n' ${name}
                ${task flake ""}
                printf '```\n\n## `nk graph`\n\n```mermaid\n'
                ${task flake "graph"}
                printf '```\n'
              } > "$out"
            ''
          ) fixtures;
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
          process-compose.dev.settings.processes.try-fixture = {
            description = "Copy a fixture into a new Git repository using this checkout, to try it out";
            disabled = true;
            command = pkgs.writeShellApplication {
              name = "try-fixture";
              runtimeInputs = [
                pkgs.git
                pkgs.gnused
              ];
              text = ''
                root="$(git rev-parse --show-toplevel)"
                case "''${1-}" in
                  ${lib.concatStringsSep "|" (lib.attrNames fixtures)}) ;;
                  *)
                    echo "Usage: nk try-fixture <${lib.concatStringsSep "|" (lib.attrNames fixtures)}>" >&2
                    exit 1
                    ;;
                esac
                # Not $TMPDIR: `nix develop` deletes its own when it exits.
                scratch="$(mktemp -d "/tmp/nk-$1.XXXXXX")"
                cp -R "$root/tests/fixtures/$1/." "$scratch"
                sed -i "s|nullkomma.url = .*|nullkomma.url = \"git+file://$root\";|" "$scratch/flake.nix"
                git -C "$scratch" init -q
                git -C "$scratch" add -A
                echo "cd $scratch && nix develop"
              '';
            };
          };
          process-compose.dev.settings.processes.update-snapshots = {
            description = "Rewrite tests/snapshots from the fixtures, after reviewing the snapshot checks' diffs";
            disabled = true;
            command = pkgs.writeShellApplication {
              name = "update-snapshots";
              text = lib.concatMapStrings (name: ''
                install -m 644 "$(nix build --no-link --print-out-paths .#legacyPackages.${system}.snapshots.${name})" tests/snapshots/${name}.md
              '') (lib.attrNames snapshots);
            };
          };
          process-compose.dev.settings.processes.check-fixtures = {
            description = "Check a real consumer flake accepts valid input and rejects formatting drift";
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
                mkdir "$scratch/project"
                cp "$root/tests/fixtures/md/flake.nix" "$root/tests/fixtures/md/README.md" "$scratch/project/"
                check() {
                  nix flake check "path:$scratch/project" \
                    --override-input nullkomma "path:$root" \
                    --no-write-lock-file --print-build-logs
                }
                check
                cp -R "$root/tests/fixtures/r" "$scratch/r"
                rm "$scratch/r/pkg.lock"
                # Bootstrapping must not evaluate the lock-dependent R environment.
                nix eval --raw "path:$scratch/r#apps.${system}.r-lock.program" \
                  --override-input nullkomma "path:$root" \
                  --no-write-lock-file > /dev/null
                if nix eval "path:$scratch/r#devShells.${system}.default.drvPath" \
                  --override-input nullkomma "path:$root" \
                  --no-write-lock-file > "$scratch/missing-lock.log" 2>&1; then
                  echo "R environment without pkg.lock unexpectedly evaluated" >&2
                  exit 1
                fi
                grep -qF "lockfile \`pkg.lock\` of DESCRIPTION is missing" "$scratch/missing-lock.log"
                # Consumer CI lints the lock; its Nixpkgs must be visible as a root input.
                nix flake lock "path:$scratch/project" --override-input nullkomma "path:$root"
                flake-checker --no-telemetry --fail-mode "$scratch/project/flake.lock"
                rm "$scratch/project/flake.lock"
              ''
              + lib.concatMapStrings (case: ''

                printf %s ${lib.escapeShellArg case.content} > "$scratch/project/${case.file}"
                if check > "$scratch/failure.log" 2>&1; then
                  echo "Consumer with invalid ${case.file} unexpectedly passed nix flake check" >&2
                  exit 1
                fi
                cat "$scratch/failure.log"
                ${lib.concatMapStrings (entry: ''
                  grep -qF -- ${lib.escapeShellArg entry} "$scratch/failure.log"
                '') case.expect}
                rm "$scratch/project/${case.file}"
              '') (lib.attrValues rejects);
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
            ) snapshots
            // lib.mapAttrs' (
              name: case:
              lib.nameValuePair "formatting-rejects-${name}" (
                pkgs.testers.testBuildFailure' {
                  name = "nullkomma-formatting-rejects-${name}";
                  drv = (perSystem fixtures.md).treefmt.build.check (
                    pkgs.runCommandLocal "unformatted-${name}" { } ''
                      mkdir $out
                      printf '{ }\n' > $out/flake.nix
                      printf %s ${lib.escapeShellArg case.content} > $out/${case.file}
                    ''
                  );
                  expectedBuilderExitCode = 1;
                  expectedBuilderLogEntries = case.expect;
                }
              )
            ) rejects;
        };
    };
}
