# `nk` is a just menu of the `dev` tree's tasks, grouped by namespace;
# tasks without one, the project's own, form the `custom` group.
# `--unsorted` lists groups in source order: nullkomma, custom, then plugins.
# Each recipe runs its task once, as `nullkomma.sandbox` does in builds:
# prerequisites (`depends_on`) with `up`, then the task with its arguments.
# Servers, tasks that signal readiness (`ready_log_line`, `readiness_probe`)
# or depend on one, run with `up <name>` instead, as they don't exit;
# the watches of their prerequisites rerun them on changes.
{ inputs, ... }:
{
  framework =
    {
      config,
      flake-parts-lib,
      lib,
      ...
    }:
    let
      inDevShell = config.nullkomma.devShell.enable;
    in
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
            once in a copy of `nullkomma.src`; `output`, a project path,
            becomes `$out`, self-contained: symlinks are copied as their targets.
          '';
        };
        options.nullkomma.scratch = lib.mkOption {
          type = lib.types.functionTo lib.types.package;
          readOnly = true;
          description = ''
            `scratch { name, command, outputs ? [ ], keep ? [ ] }` wraps the command of a watched
            process that runs project code, so its own writes cannot restart it.
            With watching on, it runs in a private copy of its working directory,
            kept for inspection until its next run, and copies back only `outputs` whose content changed;
            `keep`, rsync patterns such as build caches, persist in the copy between runs.
            With watching off, as in `nk` and builds, it runs in place.
          '';
        };
      };
      config.nullkomma.gitignore = [ "/.nullkomma/gcroots/" ];
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
          server =
            name:
            let
              p = processes.${name};
            in
            p.ready_log_line != null
            || p.readiness_probe != null
            || lib.any server (lib.attrNames (lib.defaultTo { } p.depends_on));
          group = p: if p.namespace == "default" then "custom" else p.namespace;
          rank =
            g:
            {
              nullkomma = "0";
              custom = "1";
            }
            .${g} or "2${g}";
          recipes = lib.sortOn (t: rank t.group) (
            lib.mapAttrsToList (name: p: {
              inherit name;
              inherit (p) description;
              group = group p;
              server = server name;
            }) tasks
          );
          overlay = name: settings: pkgs.writeText "process-compose-${name}.json" (builtins.toJSON settings);
          once = overlay "once" {
            processes = lib.mapAttrs (_: _: {
              is_disabled = false;
              availability.restart = "exit_on_failure";
            }) processes;
          };
          idle = overlay "idle" { processes = lib.mapAttrs (_: _: { is_disabled = true; }) processes; };
          # One-shot tasks become MCP tools, unless they declare their own `mcp`;
          # agents start servers with the `pc_*` control tools.
          # Both run as `nk` does, since an MCP call or `pc_process_start` doesn't start `depends_on`.
          mcp = overlay "mcp" {
            mcp_server = {
              transport = "stdio";
              expose_control_tools = true;
              timeout = "1h";
            };
            processes = lib.mapAttrs (
              name: _:
              if server name then
                { command = "${lib.getExe tree.outputs.package} up ${name} -t=false"; }
              else
                {
                  command = "${lib.getExe run} ${name} @{args}";
                  mcp = {
                    type = "tool";
                    arguments = [
                      {
                        name = "args";
                        type = "string";
                        description = "Shell words passed to the task, as in `nk ${name} <args>`";
                      }
                    ];
                  };
                }
            ) (lib.filterAttrs (name: p: server name || p.description != null && !(p ? mcp)) processes);
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
          # Agents keep the server for a whole session, across `nix store gc`.
          # process-compose ignores the end of its stdin, where MCP clients that quit or crash leave it (#330):
          # relay stdin, and stop process-compose at its end or on a signal.
          mcpServer = serve "nk-mcp" [ mcp ] ''
            if command -v nix-store >/dev/null; then
              mkdir -p .nullkomma/gcroots
              nix-store --add-root .nullkomma/gcroots/nk-mcp --realise "$(dirname "$(dirname "$0")")" >/dev/null
            fi
            exec 3<&0
            fifo="$(mktemp -d)/stdin"
            mkfifo "$fifo"
            trap 'rm -r "$(dirname "$fifo")"' EXIT
            PC_NO_SERVER=1 process-compose up -t=false < "$fifo" &
            server=$!
            cat <&3 > "$fifo" &
            relay=$!
            exec 3<&-
            stop() { kill -TERM "$server" 2>/dev/null || true; }
            trap stop HUP INT TERM
            wait "$relay" || true
            stop
            wait "$server"
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
            ''
            + lib.concatMapStrings (
              t:
              ''

                [group(${builtins.toJSON t.group}), doc(${builtins.toJSON t.description})]
              ''
              + (
                if t.server then
                  ''
                    ${t.name}:
                        @exec ${lib.getExe tree.outputs.package} up ${t.name}
                  ''
                else
                  ''
                    ${t.name} *args:
                        @exec ${lib.getExe run} ${t.name} "$@"
                  ''
              )
            ) recipes
            + ''

              [group("nullkomma"), doc("Serve the tasks as MCP tools over stdio, for agents")]
              mcp:
                  @exec ${lib.getExe mcpServer}

              [group("nullkomma"), doc("Print the task dependency graph; args go to `process-compose graph` (default: -f mermaid)")]
              graph *args:
                  @exec ${lib.getExe graph} "$@"
            ''
          );
          runner =
            pkgs.writeShellApplication {
              name = "nk";
              runtimeInputs = [
                pkgs.git
                pkgs.just
              ];
              text = ''exec just --justfile ${justfile} --working-directory "$(git rev-parse --show-toplevel)" "$@"'';
            }
            // {
              tasks = lib.mapAttrs (_: p: { inherit (p) description; }) tasks;
            };
        in
        {
          taskRunners.default = runner;
          nullkomma.devShell.packages = [ runner ];
          # Generated configs start stdio servers in the dev shell, which has `nk`.
          nullkomma.agents.mcpServers.nullkomma =
            if inDevShell then
              {
                type = "stdio";
                command = "nk";
                args = [ "mcp" ];
              }
            else
              {
                type = "stdio";
                command = "nix";
                args = [
                  "run"
                  ".#taskRunners.${system}.default"
                  "--"
                  "mcp"
                ];
              };
          nullkomma.sandbox =
            {
              process,
              args ? [ ],
              output ? null,
            }:
            pkgs.runCommand process { } ''
              cp -R ${config.nullkomma.src} source
              chmod -R u+w source
              patchShebangs --build source >/dev/null
              export HOME="$PWD/home" XDG_CACHE_HOME="$PWD/cache" XDG_CONFIG_HOME="$PWD/config"
              export PC_LOG_FILE="$PWD/process-compose.log"
              mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
              cd source
              ${lib.getExe run} ${lib.escapeShellArgs ([ process ] ++ args)}
              ${if output == null then ''touch "$out"'' else ''cp -RL ${lib.escapeShellArg output} "$out"''}
            '';
          nullkomma.scratch =
            {
              name,
              command,
              outputs ? [ ],
              keep ? [ ],
            }:
            pkgs.writeShellApplication {
              name = "${name}-scratch";
              runtimeInputs = [ pkgs.rsync ];
              text = ''
                if [[ -v PC_NO_WATCH ]]; then
                  exec ${lib.getExe command} "$@"
                fi
                scratch="''${XDG_CACHE_HOME:-$HOME/.cache}/nullkomma/scratch/$(pwd | cksum | cut -d' ' -f1)/${name}"
                # A stopped run copies nothing back, even if its command handled the signal, as R does.
                trap 'exit 130' INT
                trap 'exit 143' TERM
                mkdir -p "$scratch"
                rsync --archive --delete --exclude=/.git ${
                  lib.escapeShellArgs (map (pattern: "--exclude=${pattern}") keep)
                } ./ "$scratch/"
                echo "Running in scratch copy $scratch"
                status=0
                (cd "$scratch" && ${lib.getExe command} "$@") || status=$?
                ${lib.concatMapStrings (output: ''
                  if [[ -e "$scratch"/${lib.escapeShellArg output} ]]; then
                    mkdir -p "$(dirname ${lib.escapeShellArg output})"
                    rsync --recursive --links --checksum --delete "$scratch"/${lib.escapeShellArg output} "$(dirname ${lib.escapeShellArg output})/"
                  else
                    rm -rf ${lib.escapeShellArg output}
                  fi
                '') outputs}
                exit "$status"
              '';
            };
        };
    };
}
