# Tests: plugins declare them, the framework runs each one locally (`test` task)
# and sandboxed in `nix flake check`, the way treefmt handles formatters.
{
  framework =
    {
      flake-parts-lib,
      lib,
      self,
      ...
    }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.tests = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, config, ... }:
                {
                  options = {
                    command = lib.mkOption {
                      type = lib.types.lines;
                      description = "Bash script run from the project root; arguments of `test <name>` are in `$@`.";
                    };
                    packages = lib.mkOption {
                      type = lib.types.listOf lib.types.package;
                      default = [ ];
                      description = "Packages on `PATH` while the test runs.";
                    };
                    package = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      description = "The test's command.";
                    };
                    check = lib.mkOption {
                      type = lib.types.package;
                      defaultText = lib.literalMD "`command` run in a copy of the flake's source, with shebangs patched and a writable `HOME`";
                      description = "The sandboxed run in `nix flake check`; override it for tests that need more than the source.";
                    };
                  };
                  config.package = pkgs.writeShellApplication {
                    name = "test-${name}";
                    runtimeInputs = config.packages;
                    text = config.command;
                  };
                  config.check = lib.mkDefault (
                    pkgs.runCommand "test-${name}" { } ''
                      cp -r ${self} src
                      chmod -R u+w src
                      patchShebangs --build src >/dev/null
                      export HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache" XDG_CONFIG_HOME="$PWD/config"
                      mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
                      (cd src && ${lib.getExe config.package})
                      touch $out
                    ''
                  );
                }
              )
            );
            default = { };
            description = "Test suites; each runs in the `test` task and as sandboxed `checks.<system>.test-<name>`.";
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          tests = lib.mapAttrs (_: t: t.package) config.nullkomma.tests;
        in
        lib.mkIf (tests != { }) {
          nullkomma.tasks.test = {
            description = "Run all tests, or one: test <name> [args]";
            packages = [ pkgs.git ];
            command = ''
              cd "$(git rev-parse --show-toplevel)"
              case "''${1-}" in
              ${lib.concatMapStrings (name: ''
                ${lib.escapeShellArg name}) shift; exec ${lib.getExe tests.${name}} "$@" ;;
              '') (lib.attrNames tests)}
              "") ;;
              *) echo "unknown test: $1 (have: ${toString (lib.attrNames tests)})" >&2; exit 2 ;;
              esac
              ${lib.concatMapStrings (t: ''
                ${lib.getExe t}
              '') (lib.attrValues tests)}
            '';
          };
          checks = lib.mapAttrs' (name: t: lib.nameValuePair "test-${name}" t.check) config.nullkomma.tests;
        };
    };
}
