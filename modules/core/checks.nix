# Checks: plugins declare them, the framework runs each one locally (`check` task)
# and sandboxed in `nix flake check`, the way treefmt handles formatters.
{
  framework =
    {
      flake-parts-lib,
      lib,
      ...
    }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { config, pkgs, ... }:
        let
          src = config.nullkomma.src;
        in
        {
          options.nullkomma.checks = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, config, ... }:
                {
                  options = {
                    command = lib.mkOption {
                      type = lib.types.lines;
                      description = "Bash script run from the project root; arguments of `check <name>` are in `$@`.";
                    };
                    packages = lib.mkOption {
                      type = lib.types.listOf lib.types.package;
                      default = [ ];
                      description = "Packages on `PATH` while the check runs.";
                    };
                    sandboxArgs = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      example = [ "--installed" ];
                      description = "Arguments for the sandboxed run, e.g. to select a slower, stricter variant than the local default.";
                    };
                    package = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      description = "The check's command.";
                    };
                    sandboxed = lib.mkOption {
                      type = lib.types.package;
                      defaultText = lib.literalMD "`command` run in a copy of `nullkomma.src`, with shebangs patched and a writable `HOME`";
                      description = "The sandboxed run in `nix flake check`; override it for checks that need more than the source.";
                    };
                  };
                  config.package = pkgs.writeShellApplication {
                    name = "check-${name}";
                    runtimeInputs = config.packages;
                    text = config.command;
                  };
                  config.sandboxed = lib.mkDefault (
                    pkgs.runCommand "check-${name}" { } ''
                      cp -r ${src} src
                      chmod -R u+w src
                      patchShebangs --build src >/dev/null
                      export HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache" XDG_CONFIG_HOME="$PWD/config"
                      mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
                      (cd src && ${lib.getExe config.package} ${lib.escapeShellArgs config.sandboxArgs})
                      touch $out
                    ''
                  );
                }
              )
            );
            default = { };
            description = "Checks, e.g. test suites; each runs in the `check` task and sandboxed as `checks.<system>.<name>`.";
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          commands = lib.mapAttrs (_: t: t.package) config.nullkomma.checks;
        in
        lib.mkIf (commands != { }) {
          nullkomma.tasks.check = {
            description = "Run all checks, or check <name> [args]: ${lib.concatStringsSep ", " (lib.attrNames commands)}";
            packages = [ pkgs.git ];
            command = ''
              cd "$(git rev-parse --show-toplevel)"
              case "''${1-}" in
              ${lib.concatMapStrings (name: ''
                ${lib.escapeShellArg name}) shift; exec ${lib.getExe commands.${name}} "$@" ;;
              '') (lib.attrNames commands)}
              "") ;;
              *) echo "unknown check: $1 (have: ${toString (lib.attrNames commands)})" >&2; exit 2 ;;
              esac
              ${lib.concatMapStrings (t: ''
                ${lib.getExe t}
              '') (lib.attrValues commands)}
            '';
          };
          checks = lib.mapAttrs (_: t: t.sandboxed) config.nullkomma.checks;
        };
    };
}
