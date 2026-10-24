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
                  description = "One-line description of the `dev-<name>` task.";
                };
                tasks = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Tasks to keep current; their `after` tasks are added.";
                };
              };
            }
          );
          default = { };
          description = "Background dev processes: `dev-<name>` runs these tasks with a process-compose dashboard, in `after` order and in parallel where possible.";
        };
      };
      config.perSystem =
        { config, pkgs, ... }:
        let
          tasks = config.nullkomma.tasks;
          up = inputs.up.lib { inherit lib pkgs; };
          mkTree =
            name: spec:
            let
              dir = ".nullkomma/processes/${name}";
              stamp = task: "${dir}/${task}.ok";
              members = lib.unique (lib.concatMap (task: tasks.${task}.closure) spec.tasks);
              process =
                name:
                let
                  task = tasks.${name};
                  paths =
                    lib.filter (path: builtins.pathExists (self.outPath + "/${path}")) task.watch.paths
                    ++ map stamp task.after;
                in
                {
                  inherit (task) description;
                  command = ''
                    ${lib.getExe task.step}
                    touch ${lib.escapeShellArg (stamp name)}
                  '';
                  depends_on = lib.genAttrs task.after (_: {
                    condition = "process_completed";
                  });
                  watch =
                    if task.watch == null || paths == [ ] then
                      null
                    else
                      {
                        inherit paths;
                        inherit (task.watch) ignore;
                      };
                };
              tree = up.mkProcessTree {
                name = "process-tree-${name}";
                # Relative, so watchers restart processes in this tree and not in other worktrees.
                environment = {
                  PC_SOCKET_PATH = "${dir}.sock";
                  NULLKOMMA_PROCESSES = dir;
                };
                processes = lib.genAttrs members process;
              };
            in
            pkgs.writeShellApplication {
              name = "dev-${name}";
              runtimeInputs = [ pkgs.git ];
              # Watchers need every stamp to exist; an existing one keeps its time.
              text = ''
                cd "$(git rev-parse --show-toplevel)"
                mkdir -p ${lib.escapeShellArg dir}
                for stamp in ${lib.escapeShellArgs (map stamp members)}; do
                  [[ -e "$stamp" ]] || : >"$stamp"
                done
                exec ${lib.getExe tree}
              '';
            }
            // {
              # For the processTrees flake schema.
              processes = lib.genAttrs members (task: {
                inherit (tasks.${task}) description;
                command = lib.getExe tasks.${task}.step;
              });
            };
          trees = lib.mapAttrs mkTree config.nullkomma.processTrees;
        in
        {
          processTrees = trees;
          nullkomma.tasks = lib.mapAttrs' (
            name: tree:
            lib.nameValuePair "dev-${name}" {
              skip = true;
              raw = true;
              description = config.nullkomma.processTrees.${name}.description;
              command = "exec ${lib.getExe tree}";
            }
          ) trees;
        };
    };
}
