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
            nullkomma.checks = lib.mkIf (unit.tests != { }) {
              nix-unit = {
                packages = [ pkgs.nix-unit ];
                command = ''exec nix-unit --extra-experimental-features flakes --flake ".#${attr}" "$@"'';
                sandboxed = if unit.allowNetwork then networked else run;
              };
            };
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
            nullkomma.tasks = {
              flake-checker = {
                description = "Check flake.lock for outdated or non-upstream Nixpkgs";
                packages = [ pkgs.flake-checker ];
                command = ''exec flake-checker "$@"'';
              };
              update = {
                skip = true;
                raw = true;
                description = "Update flake.lock, then refresh written and generated files using the updated flake";
                command = ''
                  nix flake update "$@"
                  status=0
                  nix develop --command nk-write-files || status=1
                  nix develop --command nk-generate-files || status=1
                  exit "$status"
                '';
              };
            };
          };
      };
    };
}
