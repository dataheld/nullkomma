# Transitional: plugins not yet migrated to process-compose-flake processes.
{
  framework =
    {
      flake-parts-lib,
      lib,
      ...
    }:
    {
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
                      example = [ "nk-r-document" ];
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
                      description = "Additional native up process attributes (health probes, shutdown, environment). Also creates a `nk-pc-up-<name>` process tree, without requiring a file watch.";
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
                            options.contentPaths = lib.mkOption {
                              type = lib.types.listOf lib.types.str;
                              default = [ ];
                              description = "Project-relative directories whose files trigger runs only when their contents change, not when rewritten identically.";
                            };
                          }
                        )
                      );
                      default = null;
                      description = "Re-run the task when these inputs (or those of its `after` tasks) change, in `nk-watch-<name>` and process trees.";
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
        { config, ... }:
        let
          cfg = config.nullkomma.tasks;
        in
        {
          packages = lib.mkMerge (
            lib.mapAttrsToList (_: task: {
              ${task.output} = lib.mkDefault task.sandboxed;
            }) (lib.filterAttrs (_: task: task.output != null) cfg)
          );
          nullkomma.devShell.packages = lib.mapAttrsToList (_: task: task.package) cfg;
        };
    };
}
