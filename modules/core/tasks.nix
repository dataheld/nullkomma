# Dev-time tasks: each is a command on the dev shell PATH (taking arguments), and
# the `tasks` runner (DeterminateSystems/up) lists them and runs them without arguments.
# `after` makes them a DAG: every entry point (command, `tasks`, `watch-<name>`,
# process trees) runs the same steps in the same order.
{ inputs, ... }:
{
  framework =
    {
      flake-parts-lib,
      lib,
      self,
      ...
    }:
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
        { pkgs, ... }@perSystem:
        let
          tasks = perSystem.config.nullkomma.tasks;
        in
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
                    after = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      example = [ "r-document" ];
                      description = "Tasks whose steps run first, transitively and once each, wherever this task runs.";
                    };
                    watch = lib.mkOption {
                      type = lib.types.nullOr (
                        lib.types.submodule {
                          options.paths = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            description = "Project-relative inputs of this step; paths missing from the flake source are skipped.";
                          };
                          options.ignore = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            description = "Globs not to watch, next to Git-ignored files.";
                          };
                        }
                      );
                      default = null;
                      description = "Re-run the task when these inputs (or those of its `after` tasks) change, in `watch-<name>` and process trees.";
                    };
                    step = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      description = "`command` alone, without the `after` tasks.";
                    };
                    package = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      description = "The task's command, after the steps of its `after` tasks; for checks and other tasks.";
                    };
                    closure = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      readOnly = true;
                      description = "This task and its transitive `after` tasks, in the order they run.";
                    };
                  };
                  config.step = pkgs.writeShellApplication {
                    inherit name;
                    runtimeInputs = config.packages;
                    text = config.command;
                  };
                  # Depth-first, keeping first occurrences: a topological order.
                  config.closure = lib.unique (lib.concatMap (dep: tasks.${dep}.closure) config.after ++ [ name ]);
                  config.package =
                    if config.after == [ ] then
                      config.step
                    else
                      pkgs.writeShellApplication {
                        inherit name;
                        text =
                          lib.concatMapStrings (dep: ''
                            ${lib.getExe tasks.${dep}.step}
                          '') (lib.init config.closure)
                          + ''
                            exec ${lib.getExe config.step} "$@"
                          '';
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
          up = inputs.up.lib { inherit lib pkgs; };
          # Defined here rather than in nullkomma.tasks, whose names they depend on.
          watches = lib.concatMapAttrs (
            name: task:
            let
              watched = lib.filter (dep: cfg.${dep}.watch != null) task.closure;
              paths = lib.filter (path: builtins.pathExists (self.outPath + "/${path}")) (
                lib.concatMap (dep: cfg.${dep}.watch.paths) watched
              );
            in
            lib.optionalAttrs (task.watch != null && paths != [ ]) {
              "watch-${name}" = up.mkWatch {
                description = "Run ${name} again whenever its inputs change";
                command = lib.getExe task.package;
                ignore = lib.concatMap (dep: cfg.${dep}.watch.ignore) watched;
                inherit paths;
              };
            }
          ) cfg;
          runner = up.mkTaskRunner {
            name = "tasks";
            description = "Project tasks (for arguments, run the listed command directly)";
            tasks =
              lib.mapAttrs (
                _: task:
                removeAttrs task [
                  "after"
                  "closure"
                  "package"
                  "packages"
                  "step"
                  "watch"
                ]
                // {
                  command = task.package;
                }
              ) cfg
              // watches;
          };
        in
        lib.mkIf (cfg != { }) {
          taskRunners.default = runner;
          nullkomma.devShell.packages =
            lib.mapAttrsToList (_: task: task.package) cfg
            ++ lib.mapAttrsToList (
              name: task:
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = task.packages;
                text = task.command;
              }
            ) watches
            ++ [ runner ];
        };
    };
}
