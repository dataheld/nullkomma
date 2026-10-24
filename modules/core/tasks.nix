# Dev-time tasks: each is a command on the dev shell PATH (taking arguments), and
# the `tasks` runner (DeterminateSystems/up) lists them and runs them without arguments.
{ inputs, ... }:
{
  framework =
    { flake-parts-lib, lib, ... }:
    {
      imports = [
        (inputs.flake-parts.lib.mkTransposedPerSystemModule {
          name = "taskRunners";
          option = lib.mkOption {
            type = lib.types.lazyAttrsOf lib.types.package;
            default = { };
            description = "[up](https://github.com/DeterminateSystems/up) task runners, exported as `taskRunners.<system>`.";
          };
          file = ./tasks.nix;
        })
      ];
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        { pkgs, ... }:
        {
          options.nullkomma.tasks = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, config, ... }:
                {
                  freeformType = lib.types.attrsOf lib.types.anything;
                  options = {
                    description = lib.mkOption {
                      type = lib.types.str;
                      description = "One-line description, shown by `tasks`.";
                    };
                    command = lib.mkOption {
                      type = lib.types.lines;
                      description = "Bash script (checked by shellcheck); arguments are in `$@`.";
                    };
                    packages = lib.mkOption {
                      type = lib.types.listOf lib.types.package;
                      default = [ ];
                      description = "Packages on `PATH` while the task runs.";
                    };
                    package = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      description = "The task's command, for checks and other tasks.";
                    };
                  };
                  config.package = pkgs.writeShellApplication {
                    inherit name;
                    runtimeInputs = config.packages;
                    text = config.command;
                  };
                }
              )
            );
            default = { };
            description = ''
              Dev-time project tasks, as dev shell commands. Other attributes (`skip`, `raw`, `confirm`, …)
              are passed to the up task; see https://github.com/DeterminateSystems/up#task-attributes.
            '';
          };
        }
      );
      config.perSystem =
        { config, pkgs, ... }:
        let
          cfg = config.nullkomma.tasks;
          runner = (inputs.up.lib { inherit lib pkgs; }).mkTaskRunner {
            name = "tasks";
            description = "Project tasks (for arguments, run the listed command directly)";
            tasks = lib.mapAttrs (
              _: task:
              removeAttrs task [
                "package"
                "packages"
              ]
              // {
                command = task.package;
              }
            ) cfg;
          };
        in
        lib.mkIf (cfg != { }) {
          taskRunners.default = runner;
          nullkomma.devShell.packages = lib.mapAttrsToList (_: task: task.package) cfg ++ [ runner ];
        };
    };
}
