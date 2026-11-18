{
  plugins.nix =
    {
      config,
      flake-parts-lib,
      inputs,
      lib,
      self,
      ...
    }:
    let
      cfg = config.nullkomma;
      unitTests = lib.mapAttrs (_: c: c.nullkomma.nix.unit.tests) config.allSystems;
    in
    {
      # Where flake-parts' partitions module is imported, as `lib.mkFlake` does.
      imports = [
        (
          { options, ... }:
          {
            config = lib.optionalAttrs (options ? partitionedAttrs) {
              partitionedAttrs.tests = lib.mkIf (cfg.nix.enable && config.partitions ? dev) (
                lib.mkDefault "dev"
              );
            };
          }
        )
      ];
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.nix.unit = {
          tests = lib.mkOption {
            type = lib.types.lazyAttrsOf lib.types.raw;
            default = { };
            example = lib.literalExpression "{ testAdd = { expr = 1 + 1; expected = 2; }; }";
            description = "[nix-unit](https://github.com/nix-community/nix-unit) tests, exported as `tests.systems.<system>`; if any, they become the `nix-unit` check.";
          };
          inputs = lib.mkOption {
            type = lib.types.attrsOf lib.types.path;
            default = lib.mapAttrs (_: i: i.outPath) (removeAttrs inputs [ "self" ]);
            defaultText = lib.literalMD "the flake's inputs";
            description = "Inputs passed to nix-unit's sandboxed evaluation with `--override-input`, so it needn't fetch them.";
          };
          allowNetwork = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the sandboxed nix-unit run may fetch, e.g. inputs of inputs.";
          };
        };
      };
      config = lib.mkIf cfg.nix.enable {
        nullkomma.agents.skills.nk-upgrade = ./_nix/nk-upgrade;
        nullkomma.lint.jscpd.formatsExts.nix = lib.mkDefault [ "nix" ];
        # Unconditional: deciding by the tests would make every output depend on every system.
        flake = {
          tests.systems = unitTests;
          schemas.tests = {
            version = 1;
            doc = "[nix-unit](https://github.com/nix-community/nix-unit) tests by system, run by `checks.<system>.nix-unit`.";
            inventory = output: {
              children.systems.children = builtins.mapAttrs (system: _: {
                what = "nix-unit test suite";
                forSystems = [ system ];
              }) output.systems;
            };
          };
        };
        nullkomma.gitignore = [
          "result"
          "result-*"
        ];
        perSystem =
          {
            config,
            pkgs,
            system,
            ...
          }:
          let
            inherit (config.nullkomma) editor;
            format = if editor.formatter == null then null else editor.formatter.command;
            unit = config.nullkomma.nix.unit;
            attr = "tests.systems.${system}";
            run = pkgs.runCommand "check-nix-unit" { nativeBuildInputs = [ pkgs.nix-unit ]; } ''
              # An empty NIX_CONF_DIR hides the host's nix.conf, whose settings nix-unit's Nix may not know.
              mkdir home conf && export HOME="$PWD/home" NIX_CONF_DIR="$PWD/conf"
              unset NIX_STORE
              export NIX_STORE_DIR=${builtins.storeDir}
              export NIX_REMOTE="$HOME/storedata"
              nix-unit \
                --extra-experimental-features flakes \
                --accept-flake-config \
                ${
                  lib.concatStrings (lib.mapAttrsToList (name: path: "--override-input ${name} ${path} ") unit.inputs)
                }--flake ${lib.escapeShellArg "${self}#${attr}"}
              touch $out
            '';
            # A fixed-output derivation gets network access; its output only depends on the run's inputs.
            networked =
              let
                key = "${builtins.unsafeDiscardStringContext run.drvPath} passed\n";
              in
              run.overrideAttrs (old: {
                SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
                NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
                buildCommand = old.buildCommand + ''
                  printf %s ${lib.escapeShellArg key} > $out
                '';
                outputHashAlgo = "sha256";
                outputHashMode = "flat";
                outputHash = builtins.hashString "sha256" key;
              });
          in
          {
            nullkomma.editor.languageServers.nixd = {
              package = pkgs.nixd;
              command = [ "nixd" ];
              filetypes = [ "nix" ];
              settings = lib.optionalAttrs (format != null) { nixd.formatting.command = format; };
            };
            nullkomma.editor.vscode = {
              extensions = [ "jnoortheen.nix-ide" ];
              settings = lib.mapAttrs (_: lib.mkDefault) (
                {
                  "nix.enableLanguageServer" = true;
                  "nix.serverPath" = "nixd";
                  "nix.serverSettings" = editor.languageServers.nixd.settings;
                }
                // lib.optionalAttrs (format != null) { "nix.formatterPath" = format; }
              );
            };
            treefmt.programs = {
              nixfmt.enable = lib.mkDefault true;
              deadnix.enable = lib.mkDefault true;
              nixf-diagnose.enable = lib.mkDefault true;
            };
            process-compose.dev.settings.processes = {
              flake-checker = {
                namespace = "nix";
                description = "Check that flake.lock pins a recent, upstream Nixpkgs";
                command = "${lib.getExe pkgs.flake-checker} --fail-mode --no-telemetry";
                watch.paths = [ { path = "flake.lock"; } ];
              };
              flake-update = {
                namespace = "nix";
                description = "Update flake inputs in flake.lock and dev/flake.lock, all or those named, then write-files and generate-files";
                disabled = true;
                # Uses the project's own `nix`, which may differ from Nixpkgs'.
                command = pkgs.writeShellApplication {
                  name = "flake-update";
                  runtimeInputs = [ pkgs.jq ];
                  text = ''
                    flakes=(.)
                    if [[ -f dev/flake.nix ]]; then
                      flakes+=(./dev)
                    fi
                    # The names after the flake that its flake.lock has as inputs.
                    locked() {
                      if [[ -f $1/flake.lock ]]; then
                        jq -r '.nodes[.root].inputs | keys[] | select(IN($ARGS.positional[]))' --args "''${@:2}" < "$1/flake.lock"
                      fi
                    }
                    for name in "$@"; do
                      if [[ -z $(for flake in "''${flakes[@]}"; do locked "$flake" "$name"; done) ]]; then
                        echo "flake-update: no flake.lock here has the input '$name'" >&2
                        exit 1
                      fi
                    done
                    for flake in "''${flakes[@]}"; do
                      mapfile -t names < <(locked "$flake" "$@")
                      if (($# == 0 || ''${#names[@]} > 0)); then
                        nix flake update --flake "$flake" "''${names[@]}"
                      fi
                    done
                    status=0
                    nix develop --command nk write-files || status=1
                    nix develop --command nk generate-files || status=1
                    exit "$status"
                  '';
                };
              };
              all.depends_on.flake-checker.condition = "process_completed_successfully";
              nix-unit = lib.mkIf (unit.tests != { }) {
                namespace = "nix";
                description = "Run the nix-unit tests";
                command = ''${lib.getExe pkgs.nix-unit} --extra-experimental-features flakes --flake ".#${attr}"'';
                watch.paths = [
                  {
                    path = ".";
                    include = [
                      "*.nix"
                      "flake.lock"
                    ];
                  }
                ];
              };
              check.depends_on.nix-unit = lib.mkIf (unit.tests != { }) {
                condition = "process_completed_successfully";
              };
            };
            checks = lib.mkIf (unit.tests != { }) {
              nix-unit = if unit.allowNetwork then networked else run;
            };
          };
      };
    };
}
