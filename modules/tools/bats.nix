# Shell tests with bats: a `test` task for the fast local loop, and the same
# suite as a sandboxed `nix flake check` against the flake's source.
{
  plugins.bats =
    {
      config,
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    let
      inherit (config.nullkomma.bats) testDir;
    in
    {
      options.nullkomma.bats.testDir = lib.mkOption {
        type = lib.types.str;
        default = "test";
        description = "Directory with the `.bats` files, relative to the project root.";
      };
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.bats = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            example = lib.literalExpression "[ pkgs.jq pkgs.curl ]";
            description = "Packages on `PATH` while the tests run, in the `test` task and the check.";
          };
          libraries = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            example = lib.literalExpression "[ pkgs.bats.libraries.bats-support pkgs.bats.libraries.bats-assert ]";
            description = "[bats libraries](https://bats-core.readthedocs.io/en/stable/writing-tests.html#bats-load-library-load-a-system-wide-library), loadable with `bats_load_library`.";
          };
        };
      };
      config = lib.mkIf config.nullkomma.bats.enable {
        nullkomma.editor.vscode.extensions = [ "jetmartin.bats" ];
        perSystem =
          { config, pkgs, ... }:
          let
            cfg = config.nullkomma.bats;
            bats = if cfg.libraries == [ ] then pkgs.bats else pkgs.bats.withLibraries (_: cfg.libraries);
          in
          {
            nullkomma.devshell.packages = [ bats ];
            treefmt.settings.formatter = lib.genAttrs [ "shellcheck" "shfmt" ] (_: {
              includes = [ "*.bats" ];
            });
            nullkomma.tasks.test = {
              description = "Run the bats tests (arguments go to bats)";
              packages = [
                bats
                pkgs.git
              ]
              ++ cfg.packages;
              command = ''
                root="$(git rev-parse --show-toplevel)"
                exec bats "$@" "$root"/${lib.escapeShellArg testDir}
              '';
            };
            checks.bats =
              pkgs.runCommand "bats"
                {
                  nativeBuildInputs = [ bats ] ++ cfg.packages;
                }
                ''
                  cp -r ${self} src
                  chmod -R u+w src
                  patchShebangs --build src >/dev/null
                  export HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache" XDG_CONFIG_HOME="$PWD/config"
                  mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
                  bats --formatter tap src/${lib.escapeShellArg testDir}
                  touch $out
                '';
          };
      };
    };
}
