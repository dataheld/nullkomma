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
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.tests = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
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
              };
            }
          );
          default = { };
          description = "Test suites; each runs in the `test` task and as sandboxed `checks.<system>.test-<name>`.";
        };
      };
      config.perSystem =
        { config, pkgs, ... }:
        let
          tests = lib.mapAttrs (
            name: t:
            pkgs.writeShellApplication {
              name = "test-${name}";
              runtimeInputs = t.packages;
              text = t.command;
            }
          ) config.nullkomma.tests;
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
          # Against the flake's source, with shebangs patched and a writable HOME.
          checks = lib.mapAttrs' (
            name: test:
            lib.nameValuePair "test-${name}" (
              pkgs.runCommand "test-${name}" { } ''
                cp -r ${self} src
                chmod -R u+w src
                patchShebangs --build src >/dev/null
                export HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache" XDG_CONFIG_HOME="$PWD/config"
                mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
                (cd src && ${lib.getExe test})
                touch $out
              ''
            )
          ) tests;
        };
    };
}
