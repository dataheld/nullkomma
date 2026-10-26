# Process trees: tasks and their `after` DAG as process-compose processes
# (DeterminateSystems/up), each run again when its watched inputs change.
# A task that succeeds touches a stamp, which its dependents watch, so a failing
# step leaves them at their last good state.
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
          name = "processTrees";
          option = lib.mkOption {
            type = lib.types.lazyAttrsOf lib.types.package;
            default = { };
            description = "[up](https://github.com/DeterminateSystems/up) process trees, exported as `processTrees.<system>`.";
          };
          file = ./processes.nix;
        })
      ];
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.processTrees = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                description = lib.mkOption {
                  type = lib.types.str;
                  description = "One-line description of the `pc-up-<name>` task.";
                };
                tasks = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Tasks to keep current; their `after` tasks are added.";
                };
              };
            }
          );
          default = { };
          description = "Background dev processes: `pc-up-<name>` runs these tasks with a process-compose dashboard, in `after` order and in parallel where possible.";
        };
      };
      config.nullkomma.gitignore = [ "/.nullkomma/processes/" ];
      config.perSystem =
        { config, pkgs, ... }:
        let
          tasks = config.nullkomma.tasks;
          mkTree =
            name: spec:
            let
              dir = ".nullkomma/processes/${name}";
              stamp = task: "${dir}/${task}.ok";
              members = lib.unique (lib.concatMap (task: tasks.${task}.closure) spec.tasks);
              allWatched = lib.filter (task: tasks.${task}.watch != null) (lib.attrNames tasks);
              outputs = lib.unique (
                lib.concatMap (
                  name: lib.optionals (tasks.${name}.watch != null) tasks.${name}.watch.outputs
                ) allWatched
              );
              up = inputs.up.lib {
                inherit lib;
                pkgs = pkgs // {
                  watchexec = import ./_watch.nix {
                    inherit lib pkgs;
                    contentPaths = lib.unique (
                      lib.concatMap (
                        name: lib.optionals (tasks.${name}.watch != null) tasks.${name}.watch.contentPaths
                      ) allWatched
                    );
                  };
                };
              };
              process =
                name:
                let
                  task = tasks.${name};
                  settings = if task.process == null then { } else task.process;
                  paths =
                    lib.optionals (task.watch != null) (
                      lib.filter (path: builtins.pathExists (self.outPath + "/${path}")) task.watch.paths
                      ++ lib.optional (task.watch.manifest != null) "@${task.watch.manifest}"
                    )
                    ++ map stamp task.after;
                  watch =
                    settings.watch or (
                      if (task.watch != null && task.watch.native) || paths == [ ] then
                        null
                      else
                        {
                          inherit paths;
                          ignore = if task.watch == null then [ ] else task.watch.ignore;
                        }
                    );
                in
                assert lib.assertMsg (
                  !(settings ? command)
                ) "Set the workflow command on nullkomma.tasks.${name}, not process.command.";
                settings
                // {
                  inherit (task) description;
                  command = ''
                    ${lib.getExe task.step}
                    touch "$NULLKOMMA_ROOT"/${lib.escapeShellArg (stamp name)}
                  '';
                  depends_on =
                    lib.genAttrs task.after (_: {
                      condition = "process_completed";
                    })
                    // (settings.depends_on or { });
                  watch = if watch == null then null else watch // { ignore = outputs ++ (watch.ignore or [ ]); };
                };
              tree = up.mkProcessTree {
                name = "process-tree-${name}";
                # Share a per-run socket with watchers, outside the source tree.
                environment = {
                  PC_SOCKET_PATH = "\${TMPDIR:-/tmp}/nk-$$.sock";
                  NULLKOMMA_PROCESSES = dir;
                };
                processes = lib.genAttrs members process;
              };
            in
            pkgs.writeShellApplication {
              name = "pc-up-${name}";
              meta.description = spec.description;
              runtimeInputs = [ pkgs.git ];
              # Watchers need every stamp to exist; an existing one keeps its time.
              text = ''
                cd "$(git rev-parse --show-toplevel)"
                export NULLKOMMA_ROOT="$PWD"
                mkdir -p ${lib.escapeShellArg dir}
                ${lib.concatMapStrings (task: ''
                  [[ -e ${lib.escapeShellArg (stamp task)} ]] || : >${lib.escapeShellArg (stamp task)}
                '') members}
                exec ${lib.getExe tree}
              '';
            }
            // {
              # For the processTrees flake schema.
              processes = lib.genAttrs members process;
            };
          defaults = lib.mapAttrs (name: task: {
            inherit (task) description;
            tasks = [ name ];
          }) (lib.filterAttrs (_: task: task.watch != null || task.process != null) tasks);
          trees = lib.mapAttrs mkTree (defaults // config.nullkomma.processTrees);
        in
        {
          processTrees = trees;
        };
    };
}
