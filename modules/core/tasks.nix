# Workflows: each is a command on the dev shell PATH (taking arguments), and
# the `tasks` runner (DeterminateSystems/up) lists them and runs them without arguments.
# `after` makes them a DAG: every entry point (command, `tasks`, `watch-<name>`,
# process trees and sandboxed outputs) runs the same steps in the same order.
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
                      default = name;
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
                    before = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      description = "Tasks that run after this one, using up's native ordering convention.";
                    };
                    working_dir = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Project-relative working directory, in both the checkout and sandbox; null preserves the caller's directory.";
                    };
                    output = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      example = "site";
                      description = "Export this workflow as `packages.<output>`. The same command and prerequisites run on `nullkomma.src`, with `NULLKOMMA_OUTPUT` set to the output path.";
                    };
                    sandboxArgs = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      description = "Arguments for the sandboxed run, e.g. `--installed` to test the installed package.";
                    };
                    sandboxed = lib.mkOption {
                      type = lib.types.package;
                      readOnly = true;
                      description = "This workflow and its prerequisites run in an isolated copy of `nullkomma.src`.";
                    };
                    process = lib.mkOption {
                      type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
                      default = null;
                      description = "Additional native up process attributes (health probes, shutdown, environment). Also creates a `dev-<name>` process tree, without requiring a file watch.";
                    };
                    watch = lib.mkOption {
                      type = lib.types.nullOr (
                        lib.types.submodule (
                          { config, ... }: {
                            options.native = lib.mkOption {
                              type = lib.types.bool;
                              default = false;
                              description = "The command owns its watcher/dependency graph. Run it as a service without an outer watchexec watcher.";
                            };
                            options.manifest = lib.mkOption {
                              type = lib.types.nullOr (lib.types.either lib.types.path lib.types.package);
                              default = null;
                              description = "Immutable newline-separated input paths from a tool, passed to watchexec's --watch-file. Paths are relative to the checkout root. A changed manifest requires restarting the watcher.";
                            };
                            options.paths = lib.mkOption {
                              type = lib.types.listOf lib.types.str;
                              default = if config.native || config.manifest != null then [ ] else [ "." ];
                              description = "Project-relative inputs; prefer `.` to include new and Git-ignored inputs, excluding only known outputs. Paths missing from the flake source are skipped.";
                            };
                            options.ignore = lib.mkOption {
                              type = lib.types.listOf lib.types.str;
                              default = [ ];
                              description = "Known output globs not to watch. Git ignore files are deliberately not used as build-input filters.";
                            };
                            options.outputs = lib.mkOption {
                              type = lib.types.listOf lib.types.str;
                              default = [ ];
                              description = "Known output globs excluded from watches of this graph, including prerequisites. Declare every output to prevent feedback loops; never use Git ignores as a proxy.";
                            };
                          }
                        )
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
                  config.after =
                    assert lib.assertMsg (lib.all (
                      dep: builtins.hasAttr dep tasks
                    ) config.before) "Unknown task in nullkomma.tasks.${name}.before";
                    lib.filter (dep: lib.elem name tasks.${dep}.before) (lib.attrNames tasks);
                  config.step = pkgs.writeShellApplication {
                    inherit name;
                    runtimeInputs = config.packages ++ lib.optional (config.working_dir != null) pkgs.git;
                    text =
                      lib.optionalString (config.working_dir != null) ''
                        cd "''${NULLKOMMA_ROOT:-$(git rev-parse --show-toplevel)}"/${lib.escapeShellArg config.working_dir}
                      ''
                      + config.command;
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
                  config.sandboxed = pkgs.runCommand "workflow-${name}" { } ''
                    cp -R ${perSystem.config.nullkomma.src} source
                    chmod -R u+w source
                    patchShebangs --build source >/dev/null
                    export NULLKOMMA_ROOT="$PWD/source"
                    export HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache" XDG_CONFIG_HOME="$PWD/config"
                    mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
                    ${lib.optionalString (config.output != null) ''export NULLKOMMA_OUTPUT="$out"''}
                    cd source
                    ${lib.getExe config.package} ${lib.escapeShellArgs config.sandboxArgs}
                    ${lib.optionalString (config.output == null) "touch \"$out\""}
                  '';
                }
              )
            );
            default = { };
            description = ''
              Project workflows shared by dev shell commands, sandboxed outputs and process trees. Other attributes (`skip`, `raw`, `confirm`, …)
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
          devs = lib.mapAttrs' (
            name: tree:
            lib.nameValuePair "dev-${name}" {
              skip = true;
              raw = true;
              description = tree.meta.description or "Run ${name}";
              command = "exec ${lib.getExe tree}";
            }
          ) config.processTrees;
          # Defined here rather than in nullkomma.tasks, whose names they depend on.
          watches = lib.concatMapAttrs (
            name: task:
            let
              watched = lib.filter (dep: cfg.${dep}.watch != null) task.closure;
              manifests = lib.concatMap (
                dep: lib.optional (cfg.${dep}.watch.manifest != null) cfg.${dep}.watch.manifest
              ) watched;
              paths =
                lib.filter (path: builtins.pathExists (self.outPath + "/${path}")) (
                  lib.concatMap (dep: cfg.${dep}.watch.paths) watched
                )
                ++ lib.optional (manifests != [ ]) "@${pkgs.concatText "workflow-inputs.txt" manifests}";
            in
            lib.optionalAttrs (task.watch != null && !task.watch.native && paths != [ ]) {
              "watch-${name}" = up.mkWatch {
                description = "Run ${name} again whenever its inputs change";
                package = import ./_watch.nix { inherit lib pkgs; } (lib.getAttrs task.closure cfg);
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
                  "working_dir"
                  "output"
                  "sandboxArgs"
                  "sandboxed"
                  "process"
                  "package"
                  "packages"
                  "step"
                  "watch"
                ]
                // {
                  command = task.step;
                  # Up runs direct prerequisites; provide the transitive set once.
                  after = lib.init task.closure;
                  description =
                    task.description
                    + lib.optionalString (task.after != [ ]) " (after: ${lib.concatStringsSep ", " task.after})"
                    + lib.optionalString (task.output != null) " (build: .#${task.output})";
                }
              ) cfg
              // watches
              // devs;
          };
        in
        lib.mkIf (cfg != { }) {
          taskRunners.default = runner;
          packages = lib.mkMerge (
            lib.mapAttrsToList (_: task: {
              ${task.output} = lib.mkDefault task.sandboxed;
            }) (lib.filterAttrs (_: task: task.output != null) cfg)
          );
          nullkomma.devShell.packages =
            lib.mapAttrsToList (_: task: task.package) cfg
            ++ lib.mapAttrsToList (
              name: task:
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = task.packages or [ ];
                text = task.command;
              }
            ) (watches // devs)
            ++ [ runner ];
        };
    };
}
