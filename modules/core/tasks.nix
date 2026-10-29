# `tasks` is a just menu of the `dev` tree's tasks, grouped by namespace.
# Each recipe runs its task once, as `nullkomma.sandbox` does in builds:
# prerequisites (`depends_on`) with `up`, then the task with its arguments.
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
            description = "Task runners with a `tasks` attribute ([up](https://github.com/DeterminateSystems/up)'s schema), exported as `taskRunners.<system>`.";
          };
          file = ./tasks.nix;
        })
      ];
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.sandbox = lib.mkOption {
          type = lib.types.functionTo lib.types.package;
          readOnly = true;
          description = ''
            `sandbox { process, args ? [ ], output ? null }` runs a task of the `dev` tree
            once in a copy of `nullkomma.src`; `output`, a project path, becomes `$out`.
          '';
        };
      };
      config.perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          tree = config.process-compose.dev;
          inherit (tree.settings) processes;
          tasks = lib.filterAttrs (_: p: p.description != null) processes;
          overlay = name: settings: pkgs.writeText "process-compose-${name}.json" (builtins.toJSON settings);
          once = overlay "once" {
            processes = lib.mapAttrs (_: _: {
              is_disabled = false;
              availability.restart = "exit_on_failure";
            }) processes;
          };
          idle = overlay "idle" { processes = lib.mapAttrs (_: _: { is_disabled = true; }) processes; };
          # One-shot tasks become MCP tools; agents start services with the `pc_*` control tools.
          # Tools run through `nk-run`, as an MCP call does not start `depends_on`.
          mcp = overlay "mcp" {
            mcp_server = {
              transport = "stdio";
              expose_control_tools = true;
            };
            processes = lib.mapAttrs (name: _: {
              command = "${lib.getExe run} ${name} @{args}";
              mcp = {
                type = "tool";
                arguments = [
                  {
                    name = "args";
                    type = "string";
                    description = "Shell words passed to the task, as in `tasks ${name} <args>`";
                  }
                ];
              };
            }) (lib.filterAttrs (_: p: p.disabled == true) tasks);
          };
          # Graph and MCP commands need a project, but no process started.
          serve =
            name: files: text:
            pkgs.writeShellApplication {
              inherit name text;
              runtimeInputs = [ tree.package ];
              runtimeEnv.PC_CONFIG_FILES = lib.concatMapStringsSep "," toString (
                [
                  tree.outputs.settingsFile
                  idle
                ]
                ++ files
              );
            };
          mcpServer = serve "nk-mcp" [ mcp ] ''
            PC_NO_SERVER=1 exec process-compose up -t=false
          '';
          graph = serve "nk-graph" [ ] ''
            [ $# -gt 0 ] || set -- -f mermaid
            PC_SOCKET_PATH="$(mktemp -u)"
            export PC_SOCKET_PATH
            process-compose up -D >/dev/null
            trap 'process-compose down >/dev/null' EXIT
            process-compose project is-ready --wait >/dev/null
            process-compose graph "$@"
          '';
          run = pkgs.writeShellApplication {
            name = "nk-run";
            runtimeInputs = [ tree.package ];
            runtimeEnv = {
              PC_CONFIG_FILES = "${tree.outputs.settingsFile},${once}";
              PC_NO_SERVER = "1";
              PC_NO_WATCH = "1";
            };
            # `run` shows only the task's output, so its prerequisites run first.
            text = ''
              process="$1"
              shift
              case "$process" in
              ${lib.concatStrings (
                lib.mapAttrsToList (name: p: ''
                  ${lib.escapeShellArg name}) process-compose up ${lib.escapeShellArgs (lib.attrNames p.depends_on)} -t=false ;;
                '') (lib.filterAttrs (_: p: p.depends_on != null) processes)
              )}
              esac
              # `run` passes arguments through a shell.
              exec process-compose run "$process" --no-deps -- ''${@:+$(printf '%q ' "$@")}
            '';
          };
          justfile = pkgs.writeText "justfile" (
            ''
              set shell := ["bash", "-euo", "pipefail", "-c"]
              set positional-arguments

              [private]
              default:
                  @just --justfile {{justfile()}} --list --unsorted

              [doc("Serve the tasks as MCP tools over stdio, for agents")]
              mcp:
                  @exec ${lib.getExe mcpServer}

              [doc("Print the process dependency graph; args go to `process-compose graph` (default: -f mermaid)")]
              graph *args:
                  @exec ${lib.getExe graph} "$@"
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (name: p: ''

                [group(${builtins.toJSON p.namespace})]
                [doc(${builtins.toJSON p.description})]
                ${name} *args:
                    @exec ${lib.getExe run} ${name} "$@"
              '') tasks
            )
          );
          runner =
            pkgs.writeShellApplication {
              name = "tasks";
              runtimeInputs = [
                pkgs.git
                pkgs.just
              ];
              text = ''exec just --justfile ${justfile} --working-directory "$(git rev-parse --show-toplevel)" "$@"'';
            }
            // {
              tasks = lib.mapAttrs (_: p: { inherit (p) description; }) tasks;
              # Launches `tasks mcp` without the dev shell, whose hooks may write to stdout.
              mcpServer = {
                command = "nix";
                args = [
                  "run"
                  ".#taskRunners.${system}.default"
                  "--"
                  "mcp"
                ];
              };
            };
        in
        {
          taskRunners.default = runner;
          nullkomma.devShell.packages = [ runner ];
          nullkomma.files.".mcp.json" = {
            mode = lib.mkDefault "generated";
            text = builtins.toJSON { mcpServers.nullkomma = runner.mcpServer; };
          };
          nullkomma.sandbox =
            {
              process,
              args ? [ ],
              output ? null,
            }:
            pkgs.runCommand "nk-${process}" { } ''
              cp -R ${config.nullkomma.src} source
              chmod -R u+w source
              patchShebangs --build source >/dev/null
              export HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache" XDG_CONFIG_HOME="$PWD/config"
              export PC_LOG_FILE="$PWD/process-compose.log"
              mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
              cd source
              ${lib.getExe run} ${lib.escapeShellArgs ([ process ] ++ args)}
              ${if output == null then ''touch "$out"'' else ''cp -R ${lib.escapeShellArg output} "$out"''}
            '';
        };
    };
}
