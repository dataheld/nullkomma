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
      fixtures = lib.genAttrs [ "md" "quarto" "quarto-branded" "r" "r-remotes" "shell" ] (
        name: callFlake (root + "/tests/fixtures/${name}")
      );
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
        in
        {
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
              ;
            raw = rawAt (root + "/tests/fixtures/md");
            # Executables of a flake's nullkomma tasks and checks.
            task = flake: name: lib.getExe (perSystem flake).nullkomma.tasks.${name}.package;
            runCheck = flake: name: lib.getExe (perSystem flake).nullkomma.checks.${name}.package;
            # What plugins can contribute to a consumer flake.
            summary = flake: {
              files = lib.attrNames (perSystem flake).nullkomma.files;
              tools = map lib.getName (perSystem flake).nullkomma.devShell.packages;
              formatters = lib.attrNames (perSystem flake).treefmt.build.programs;
              tasks = lib.attrNames (perSystem flake).nullkomma.tasks;
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
            # Shell prelude: a writable copy of `src` as the working directory, and
            # `fails <message> <command...>`, expecting the command to fail with message.
            project = src: ''
              cp -R ${src} project
              chmod -R u+w project
              cd project
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
          nullkomma.tasks.check-fixtures = {
            description = "Check a real consumer flake accepts valid input and rejects formatting drift";
            packages = [
              pkgs.coreutils
              pkgs.flake-checker
              pkgs.git
              pkgs.gnugrep
            ];
            command = ''
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
              nix build "path:$scratch/r#r-lock" \
                --override-input nullkomma "path:$root" \
                --no-write-lock-file --no-link --print-build-logs
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
          checks =
            lib.concatMapAttrs (
              name: flake:
              lib.mapAttrs' (check: lib.nameValuePair "fixture-${name}-${check}") (
                flake.checks.${system} // { devshell = flake.devShells.${system}.default; }
              )
            ) fixtures
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
