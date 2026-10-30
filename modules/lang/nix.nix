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
        partitionedAttrs.tests = lib.mkIf (config.partitions ? dev) (lib.mkDefault "dev");
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
              mkdir home && export HOME="$PWD/home"
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
            process-compose.dev.settings.processes = lib.mkMerge [
              (lib.mapAttrs
                (
                  _: p:
                  {
                    namespace = "nix";
                    disabled = true;
                  }
                  // p
                )
                {
                  flake-checker = {
                    description = "Check flake.lock for outdated or non-upstream Nixpkgs";
                    command = pkgs.flake-checker;
                  };
                  flake-update = {
                    description = "`nix flake update` flake.lock and dev/flake.lock, then write-files and generate-files; args go to `nix flake update` and skip dev/flake.lock";
                    # Uses the project's own `nix`, which may differ from Nixpkgs'.
                    command = pkgs.writeShellApplication {
                      name = "flake-update";
                      text = ''
                        nix flake update "$@"
                        if [[ $# == 0 && -f dev/flake.nix ]]; then
                          nix flake update --flake ./dev
                        fi
                        status=0
                        nix develop --command nk write-files || status=1
                        nix develop --command nk generate-files || status=1
                        exit "$status"
                      '';
                    };
                  };
                }
              )
              { all.depends_on.flake-checker.condition = "process_completed_successfully"; }
              (lib.mkIf (unit.tests != { }) {
                nix-unit = {
                  namespace = "nix";
                  description = "Run the nix-unit tests";
                  command = ''${lib.getExe pkgs.nix-unit} --extra-experimental-features flakes --flake ".#${attr}"'';
                  disabled = true;
                };
                check.depends_on.nix-unit.condition = "process_completed_successfully";
              })
            ];
            checks = lib.mkIf (unit.tests != { }) {
              nix-unit = if unit.allowNetwork then networked else run;
            };
          };
      };
    };
}
