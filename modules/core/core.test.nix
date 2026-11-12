{
  partitions.dev.module =
    { config, inputs, ... }:
    {
      perSystem =
        {
          harness,
          lib,
          pkgs,
          ...
        }:
        let
          inherit (harness)
            nullkomma
            root
            plugins
            callFlakeWith
            fixtures
            perSystem
            project
            raw
            rawAt
            summary
            task
            ;
          md = root + "/tests/fixtures/md";
          section = text: builtins.toFile "section.md" text;
          # Uses process-compose-flake options only, as external modules would.
          contract = raw {
            perSystem.process-compose.dev.settings.processes = {
              a = {
                namespace = "demo";
                description = "A";
                command = "echo a >> log";
                disabled = true;
              };
              b = {
                namespace = "demo";
                description = "B";
                command = ''echo b "$@" >> log'';
                depends_on.a.condition = "process_completed_successfully";
              };
              inspect = {
                description = "Inspect";
                command = "echo inspected";
                disabled = true;
                mcp.type = "resource";
              };
              broken = {
                description = "Broken";
                command = "exit 3";
                disabled = true;
              };
              serve = {
                command = "sleep 60";
                ready_log_line = "serving";
              };
              # Records its own and process-compose's PID.
              hold = {
                command = ''echo "$$ $PPID" > held; exec sleep 600'';
                disabled = true;
              };
              watched = {
                command = "echo w >> watched";
                disabled = true;
                watch.paths = [ { path = "trigger"; } ];
              };
              rerun = {
                description = "Rerun";
                command = ''echo r "$@" >> log'';
                watch.paths = [ { path = "trigger"; } ];
              };
              preview = {
                namespace = "demo";
                description = "Preview";
                command = "sleep 60";
                depends_on.watched.condition = "process_completed_successfully";
                depends_on.serve.condition = "process_started";
              };
            };
          };
          # A watched process writing into its own watched tree.
          isolated = raw {
            perSystem =
              { config, pkgs, ... }:
              {
                process-compose.dev.settings.processes.isolated = {
                  description = "Isolated";
                  watch.paths = [ { path = "."; } ];
                  shutdown.signal = 2;
                  command = config.nullkomma.scratch {
                    name = "isolated";
                    outputs = [ "out" ];
                    keep = [ "/cache" ];
                    command = pkgs.writeShellApplication {
                      name = "isolated";
                      text = ''
                        # Handles SIGINT and exits, as R does.
                        trap 'exit 1' INT
                        touch side-effect
                        if [ -e cache/kept ]; then echo kept >> "$KEPT"; fi
                        mkdir -p cache out
                        touch cache/kept
                        cp input out/copy
                        if grep -qx slow input; then
                          touch out/slow
                          sleep 600
                        fi
                      '';
                    };
                  };
                };
              };
          };
          # One directory watched by a process with a relative working_dir and one without.
          spellings =
            let
              watcher = {
                command = "true";
                watch.paths = [ { path = "watched"; } ];
              };
            in
            raw {
              perSystem.process-compose.dev.settings.processes = {
                in-root = watcher;
                in-working-dir = watcher // {
                  working_dir = "./";
                };
              };
            };
          privacy =
            sections:
            (raw { nullkomma.privacy = { inherit sections; }; }).debug.config.nullkomma.privacy.policy;
          fileVersions = lib.genAttrs [ "old" "new" ] (
            version:
            raw {
              perSystem.nullkomma.files = {
                "source.txt".text = version;
                "generated.txt" = {
                  text = version;
                  mode = "generated";
                  commentPrefix = "#";
                };
              }
              # Declared only by the old version, so the new one prunes them.
              // lib.optionalAttrs (version == "old") {
                "stale-generated.txt" = {
                  text = version;
                  mode = "generated";
                  commentPrefix = "#";
                };
                "notes.md" = {
                  commentPrefix = "<!--";
                  commentSuffix = " -->";
                  sections.stale = version;
                };
              };
            }
          );
          sectioned = raw {
            perSystem.nullkomma.files."notes.md" = {
              commentPrefix = "<!--";
              commentSuffix = " -->";
              sections.docs = "new\n";
            };
          };
          ciVersions = lib.genAttrs [ "old" "new" ] (
            version:
            raw {
              imports = [ plugins.github ];
              nullkomma.github = {
                enable = true;
                workflows.ref = version;
              };
            }
          );
          # A project with its own `.gitignore` lines, and a skill renamed between versions.
          ignoredVersions = lib.genAttrs [ "old" "new" ] (
            version:
            let
              directory = {
                source = md;
                mode = "generated";
                directory = true;
              };
            in
            rawAt (root + "/tests/fixtures/edited-gitignore") {
              imports = [ plugins.git ];
              nullkomma.git.enable = true;
              perSystem.nullkomma.files = {
                "generated.txt" = {
                  text = version;
                  mode = "generated";
                };
                ".agents/skills/kept" = directory;
              }
              // (
                if version == "old" then
                  { ".agents/skills/before" = directory; }
                else
                  {
                    ".agents/skills/after" = directory;
                    "added.txt" = {
                      text = version;
                      mode = "generated";
                    };
                  }
              );
            }
          );
        in
        {
          nullkomma.nix.unit.tests = {
            # keep-sorted start block=yes
            testAgentSkillsAreNamedLikeTheirDirectories =
              let
                skills =
                  config.nullkomma.agents.skills
                  // fixtures.r.debug.config.nullkomma.agents.skills
                  // lib.mapAttrs (name: _: root + "/skills/${name}") (builtins.readDir (root + "/skills"));
                named = name: dir: lib.hasInfix "\nname: ${name}\n" (builtins.readFile (dir + "/SKILL.md"));
              in
              {
                expr = lib.attrNames (lib.filterAttrs (name: dir: !named name dir) skills);
                expected = [ ];
              };
            testAgentsPluginWritesSkillsAndSection =
              let
                files =
                  enable:
                  (perSystem (raw {
                    imports = [ plugins.agents ];
                    nullkomma.agents = {
                      inherit enable;
                      skills.demo = md;
                    };
                    perSystem.nullkomma.agents.mcpServers.demo = {
                      type = "http";
                      url = "https://example.com/mcp";
                    };
                  })).nullkomma.files;
              in
              {
                expr = {
                  enabled = lib.mapAttrs (_: f: f.mode) (files true);
                  servers = lib.attrNames (builtins.fromJSON (files true).".mcp.json".text).mcpServers;
                  disabled = files false;
                };
                expected = {
                  servers = [
                    "demo"
                    "nullkomma"
                  ];
                  enabled = {
                    ".mcp.json" = "generated";
                    "AGENTS.md" = "source";
                    ".agents/skills/demo" = "generated";
                    ".agents/skills/nk-audit-output" = "generated";
                  };
                  disabled = { };
                };
              };
            testAllPluginsDisabledIsBareFramework = {
              expr = map summary [
                (raw { imports = lib.attrValues plugins; })
                (callFlakeWith {
                  nullkomma = lib.genAttrs (lib.attrNames plugins ++ [ "devShell" ]) (_: {
                    enable = false;
                  });
                } md)
              ];
              expected = lib.replicate 2 (summary (raw { }));
            };
            testChecksAreCheckDependencies = {
              expr =
                (summary (raw {
                  perSystem.process-compose.dev.settings.processes = {
                    custom.command = "true";
                    check.depends_on.custom.condition = "process_completed_successfully";
                  };
                })).checks;
              expected = [
                "custom"
                "treefmt"
              ];
            };
            testConfigsOnlyEnableTheirPlugin = {
              expr = lib.mapAttrs (p: text: import (builtins.toFile "${p}.nix" text)) nullkomma.lib.configs;
              expected = lib.mapAttrs (p: _: { nullkomma.${p}.enable = true; }) plugins;
            };
            testConsumersCustomizeDefaults =
              let
                customized = perSystem (
                  callFlakeWith {
                    perSystem = {
                      nullkomma.editor.vscode.settings."nix.serverPath" = "project-nixd";
                      treefmt.programs.deadnix.enable = false;
                    };
                  } md
                );
              in
              {
                expr = {
                  disabled = customized.treefmt.programs.deadnix.enable;
                  setting = customized.nullkomma.editor.vscode.settings."nix.serverPath";
                };
                expected = {
                  disabled = false;
                  setting = "project-nixd";
                };
              };
            testDevPartitionServesDevelopmentOutputs =
              let
                demo.perSystem = {
                  packages.demo = pkgs.hello;
                  custom = "demo";
                };
                served =
                  module:
                  let
                    flake = raw ({ transposition.custom.adHoc = true; } // module);
                    inherit (pkgs.stdenv.hostPlatform) system;
                  in
                  {
                    packages = lib.attrNames flake.packages.${system};
                    custom = flake.custom.${system};
                  };
                dev.partitions.dev = { };
              in
              {
                expr = {
                  served = map served [
                    demo
                    { partitions.dev.module = demo; }
                  ];
                  outputsEvaluate = map (outputs: lib.all lib.isAttrs (lib.attrValues outputs)) [
                    (raw dev)
                    (callFlakeWith dev md).outputs
                    (callFlakeWith (dev // { nullkomma.nix.enable = false; }) md).outputs
                  ];
                };
                expected = {
                  served = lib.replicate 2 {
                    packages = [
                      "demo"
                      "dev"
                    ];
                    custom = "demo";
                  };
                  outputsEvaluate = lib.replicate 3 true;
                };
              };
            testDevTreeRunsShellTasks = {
              expr = lib.attrNames (
                lib.filterAttrs (_: p: p.disabled != true) (perSystem fixtures.md).processTrees.dev.processes
              );
              expected = [
                "flake-checker"
                "jscpd"
                "treefmt"
              ];
            };
            testEveryPluginCanBeDisabled = {
              expr = lib.filter (
                name:
                summary (
                  callFlakeWith {
                    imports = [ { nullkomma.cloudflare.worker = "fixture-site"; } ];
                    nullkomma.${name}.enable = !fixtures.md.debug.config.nullkomma.${name}.enable;
                  } (if name == "r" then root + "/tests/fixtures/r" else md)
                ) == summary fixtures.md
              ) (lib.attrNames plugins);
              expected = [ ];
            };
            testGitignoreContainsPluginPatternsAndGeneratedFiles = {
              expr = map (flake: (perSystem flake).nullkomma.files.".gitignore".sections.git) [
                fixtures.md
                (callFlakeWith {
                  perSystem.nullkomma.files = {
                    ".vscode/settings.json".mode = "source";
                    ".vscode/extensions.json".enable = false;
                  };
                } md)
              ];
              expected = [
                (lib.concatLines [
                  "result"
                  "result-*"
                  ".direnv/"
                  "/.nullkomma/gcroots/"
                  "/.mcp.json"
                  "/.nvim.lua"
                  "/.vscode/extensions.json"
                  "/.vscode/mcp.json"
                  "/.vscode/settings.json"
                ])
                (lib.concatLines [
                  "result"
                  "result-*"
                  ".direnv/"
                  "/.nullkomma/gcroots/"
                  "/.mcp.json"
                  "/.nvim.lua"
                  "/.vscode/mcp.json"
                ])
              ];
            };
            testImportTreeSkipsUnderscoresAndNonNix =
              let
                tree = root + "/tests/fixtures/import-tree";
              in
              {
                expr = {
                  found = map (p: lib.removePrefix (toString tree) (toString p)) (nullkomma.lib.importTree tree);
                  missing = nullkomma.lib.importTree (tree + "/missing");
                };
                expected = {
                  found = [
                    "/a.nix"
                    "/sub/b.nix"
                  ];
                  missing = [ ];
                };
              };
            testImportingModulesTwiceIsHarmless =
              let
                # Import order may change list order, not contents.
                normalize =
                  v:
                  if lib.isList v then
                    lib.sort lib.lessThan v
                  else if lib.isAttrs v then
                    lib.mapAttrs (_: normalize) v
                  else
                    v;
              in
              {
                expr = normalize (
                  summary (
                    callFlakeWith {
                      # Keys make the module system import each once.
                      imports = [
                        nullkomma.flakeModules.framework
                        nullkomma.flakeModules.nix
                        nullkomma.modules.flake.nix
                        nullkomma.modules.flake.default
                      ];
                    } md
                  )
                );
                expected = normalize (summary fixtures.md);
              };
            testPluginsAddMcpServers =
              let
                servers = flake: lib.attrNames (perSystem flake).nullkomma.agents.mcpServers;
              in
              {
                expr = map servers [
                  fixtures.md
                  fixtures.cloudflare
                  fixtures.quarto
                  (callFlakeWith { nullkomma.quarto.enable = true; } (root + "/tests/fixtures/r-shiny"))
                ];
                expected = [
                  [ "nullkomma" ]
                  [
                    "cloudflare-api"
                    "cloudflare-docs"
                    "nullkomma"
                    "opentofu"
                  ]
                  [
                    "nullkomma"
                    "playwright"
                  ]
                  [
                    "nullkomma"
                    "playwright"
                    "r"
                  ]
                ];
              };
            testPrivacyPolicyOrdersEnabledSections = {
              expr = {
                policy = privacy {
                  late = {
                    order = 200;
                    markdown.en = section "Late\n";
                    markdown.de = section "Spät\n";
                  };
                  early = {
                    order = 100;
                    markdown.en = section "Early\n";
                    markdown.de = section "Früh\n";
                  };
                  disabled = {
                    enable = false;
                    markdown.en = section "Disabled\n";
                  };
                };
                empty = privacy { };
                missingLanguage =
                  (builtins.tryEval (privacy { english.markdown.en = section "Only English\n"; }).de).success;
              };
              expected = {
                policy = {
                  en = "Early\n\nLate\n";
                  de = "Früh\n\nSpät\n";
                };
                empty = { };
                missingLanguage = false;
              };
            };
            testStdioServersStartInDevShell =
              let
                servers =
                  devShell:
                  (builtins.fromJSON
                    (perSystem (raw {
                      imports = [ plugins.agents ];
                      nullkomma.agents.enable = true;
                      nullkomma.devShell.enable = devShell;
                      perSystem.nullkomma.agents.mcpServers = {
                        demo = {
                          type = "stdio";
                          command = "demo";
                          args = [ "--flag" ];
                        };
                        docs = {
                          type = "http";
                          url = "https://example.com/mcp";
                        };
                      };
                    })).nullkomma.files.".mcp.json".text
                  ).mcpServers;
                docs = {
                  type = "http";
                  url = "https://example.com/mcp";
                };
              in
              {
                expr = {
                  inDevShell = servers true;
                  withoutDevShell = servers false;
                };
                expected = {
                  inDevShell = {
                    inherit docs;
                    demo = {
                      type = "stdio";
                      command = "nix";
                      args = [
                        "develop"
                        "--command"
                        "demo"
                        "--flag"
                      ];
                    };
                    nullkomma = {
                      type = "stdio";
                      command = "nix";
                      args = [
                        "develop"
                        "--command"
                        "nk"
                        "mcp"
                      ];
                    };
                  };
                  withoutDevShell = {
                    inherit docs;
                    demo = {
                      type = "stdio";
                      command = "demo";
                      args = [ "--flag" ];
                    };
                    nullkomma = {
                      type = "stdio";
                      command = "nix";
                      args = [
                        "run"
                        ".#taskRunners.${pkgs.stdenv.hostPlatform.system}.default"
                        "--"
                        "mcp"
                      ];
                    };
                  };
                };
              };
            testTasksAllFormatsAndChecks = {
              expr = lib.attrNames (perSystem fixtures.md).processTrees.dev.processes.all.depends_on;
              expected = [
                "check"
                "flake-checker"
                "gitleaks-git"
                "treefmt"
              ];
            };
            testTasksAreDescribedProcesses =
              let
                p = perSystem contract;
              in
              {
                expr = lib.genAttrs [ "a" "b" "broken" "serve" ] (name: {
                  task = p.taskRunners.default.tasks ? ${name};
                  process = p.processTrees.dev.processes ? ${name};
                });
                expected = {
                  a = {
                    task = true;
                    process = true;
                  };
                  b = {
                    task = true;
                    process = true;
                  };
                  broken = {
                    task = true;
                    process = true;
                  };
                  serve = {
                    task = false;
                    process = true;
                  };
                };
              };
            testTemplatesAreFixtures = {
              expr = lib.mapAttrs (_: t: builtins.readFile (t.path + "/flake.nix")) nullkomma.templates;
              expected = lib.mapAttrs (
                _: _: builtins.readFile (root + "/tests/fixtures/md/flake.nix")
              ) nullkomma.templates;
            };
            # keep-sorted end
          };
          checks = {
            tasks =
              let
                tasks = lib.getExe (perSystem contract).taskRunners.default;
                sandboxed = (perSystem contract).nullkomma.sandbox {
                  process = "b";
                  args = [ "sandboxed value" ];
                  output = "log";
                };
              in
              pkgs.runCommand "nullkomma-tasks" { } ''
                ${harness.project md}
                ${lib.getExe pkgs.git} init -q
                export HOME="$TMPDIR" PC_LOG_FILE="$TMPDIR/pc.log"
                logs=(mcp.out preview.out "$PC_LOG_FILE" mcp.log)
                rewatched() { [ "$(wc -l < watched)" -eq 2 ]; }
                answered() { [ "$(grep -cE '"id":[0-9]+,' mcp.out)" -eq 5 ]; }
                ${tasks} > menu
                grep -qF '[demo]' menu
                ${tasks} b 'local value'
                printf 'a\nb local value\n' | diff - log
                if ${tasks} broken; then exit 1; fi
                printf 'a\nb sandboxed value\n' | diff - ${sandboxed}
                ${tasks} graph | grep -qF 'b --> a'
                # MCP clients stop a stdio server with SIGTERM.
                mkdir bin
                printf '#!/bin/sh\necho "$@" > %s\n' "$PWD/gcroot" > bin/nix-store
                chmod +x bin/nix-store
                mkfifo requests
                PATH="$PWD/bin:$PATH" PC_LOG_FILE="$PWD/mcp.log" ${tasks} mcp < requests > mcp.out &
                server=$!
                exec 3> requests
                # shortcut: process-compose 1.124.0 deadlocks on MCP calls before its runner
                # starts, which logs this; drop the wait once upstream serves MCP only after (#285).
                awaiting "grep -qsF 'Scheduler started' mcp.log" "$server"
                printf '%s\n' >&3 \
                  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
                  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
                  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
                  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"b","arguments":{"args":"mcp value"}}}' \
                  '{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{"uri":"process://inspect"}}' \
                  '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"pc_process_start","arguments":{"name":"preview"}}}'
                # Servers start with their prerequisites.
                awaiting 'test -e watched' "$server"
                awaiting answered "$server"
                kill "$server"
                awaiting '! kill -0 "$server" 2>/dev/null'
                rm watched
                # The server outlives `nix store gc` only with its closure rooted.
                grep -qE '^--add-root \.nullkomma/gcroots/nk-mcp --realise /nix/store/[^ ]+-nk-mcp$' gcroot
                grep -qF '"name":"b"' mcp.out
                grep -qF '"name":"pc_process_start"' mcp.out
                if grep -qF '"name":"serve"' mcp.out; then exit 1; fi
                if grep -qF '"name":"preview"' mcp.out; then exit 1; fi
                if grep -qF '"name":"inspect"' mcp.out; then exit 1; fi
                grep -qF 'inspected' mcp.out
                tail -n 1 log | grep -qx 'b mcp value'
                touch trigger
                ${tasks} rerun 'once'
                tail -n 1 log | grep -qx 'r once'
                # Servers run with their prerequisites' watches.
                PC_DISABLE_TUI=1 ${tasks} preview > preview.out 2>&1 &
                server=$!
                awaiting 'test -e watched' "$server"
                echo >> trigger
                awaiting rewatched "$server"
                kill "$server"
                touch $out
              '';
            # An MCP client that quits closes the server's stdin, then may SIGKILL it; a crashed client only closes stdin.
            mcp-without-client = pkgs.runCommand "nullkomma-mcp-without-client" { } ''
              ${harness.project md}
              ${lib.getExe pkgs.git} init -q
              export HOME="$TMPDIR"
              logs=(mcp.out mcp.log)
              mkfifo requests
              PC_LOG_FILE="$PWD/mcp.log" ${lib.getExe (perSystem contract).taskRunners.default} mcp < requests > mcp.out &
              client=$!
              exec 3> requests
              awaiting "grep -qsF 'Scheduler started' mcp.log" "$client"
              printf '%s\n' >&3 \
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
                '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
                '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"pc_process_start","arguments":{"name":"hold"}}}'
              awaiting 'test -s held' "$client"
              read -r held server < held
              trap 'kill -KILL "$held" "$server" 2>/dev/null || true' EXIT
              exec 3>&-
              kill -KILL "$client"
              awaiting "! kill -0 $server 2>/dev/null"
              awaiting "! kill -0 $held 2>/dev/null"
              touch $out
            '';
            scratch = pkgs.runCommand "nullkomma-scratch" { } ''
              ${harness.project md}
              export KEPT="$TMPDIR/kept" XDG_CACHE_HOME="$TMPDIR/cache"
              echo v1 > input
              mkdir out
              echo v1 > out/copy
              touch -d @0 out/copy
              ${harness.watching isolated "isolated"}
              settled isolated 1
              # Its own writes stay in its copy; unchanged outputs are not rewritten.
              test ! -e side-effect
              test "$(stat -c %Y out/copy)" -eq 0
              copy="$(sed -n 's/.*Running in scratch copy //p' "$TMPDIR/up.log" | head -n 1)"
              [[ "$copy" == "$XDG_CACHE_HOME"/nullkomma/scratch/* ]]
              test -e "$copy/side-effect"
              # An edit reruns it, and its changed output once more.
              echo v2 > input
              settled isolated 3
              grep -qx v2 out/copy
              [ "$(wc -l < "$KEPT")" -eq 2 ]
              # A stopped run copies nothing back.
              echo slow > input
              awaiting 'test -e "$copy/out/slow"' "$server"
              echo v3 > input
              settled isolated 6
              grep -qx v3 out/copy
              test ! -e out/slow
              kill "$server"
              wait "$server" || true
              # Without watches, it runs in place.
              ${task isolated "isolated"}
              test -e side-effect
              touch $out
            '';
            # A change restarts every process watching it, whatever its working_dir.
            watch-working-dirs = pkgs.runCommand "nullkomma-watch-working-dirs" { } ''
              ${harness.project md}
              mkdir watched
              ${harness.watching spellings "in-root in-working-dir"}
              settled in-root 1
              settled in-working-dir 1
              touch watched/change
              settled in-root 2
              settled in-working-dir 2
              touch $out
            '';
            neovim-config =
              pkgs.runCommandLocal "nullkomma-neovim-config"
                {
                  nativeBuildInputs = [
                    pkgs.neovim-unwrapped
                    (perSystem fixtures.md).treefmt.build.wrapper
                  ];
                }
                ''
                  ${harness.project md}
                  HOME=$TMPDIR nvim --clean -l ${pkgs.writeText "check.lua" ''
                    dofile("${(perSystem fixtures.md).nullkomma.files.".nvim.lua".source}")
                    assert(vim.lsp.config.nixd.cmd[1] == "nixd")
                    assert(vim.lsp.config.nixd.settings.nixd.formatting.command[1] == "treefmt")
                    assert(vim.lsp.is_enabled("nixd"))
                    vim.cmd.edit(vim.fn.fnameescape(vim.fn.getcwd() .. "/a % space.nix"))
                    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "{foo=1;}" })
                    vim.cmd.Format()
                    assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "{ foo = 1; }")
                    assert(vim.fn.filereadable("a % space.nix") == 0)
                    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
                    vim.cmd.file("format.md")
                    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Title", "", "* item" })
                    vim.cmd.Format()
                    assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[3] == "- item")
                    local failure
                    vim.notify = function(message, level)
                      assert(level == vim.log.levels.ERROR)
                      failure = message
                    end
                    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
                    vim.cmd.Format()
                    assert(failure:find("Save the buffer", 1, true))
                    failure = nil
                    dofile("${
                      (perSystem (
                        callFlakeWith {
                          perSystem.nullkomma.editor.formatter.command = lib.mkForce [
                            "sh"
                            "-c"
                            "echo formatter-failed >&2; exit 1"
                          ];
                        } md
                      )).nullkomma.files.".nvim.lua".source
                    }")
                    vim.cmd.file("broken.nix")
                    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "{" })
                    vim.cmd.Format()
                    assert(failure:find("formatter-failed", 1, true))
                    assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "{")
                  ''}
                  touch $out
                '';
            # Stdio MCP servers start in the dev shell, so its hooks must leave stdout to them.
            dev-shell-hook =
              pkgs.runCommandLocal "nullkomma-dev-shell-hook"
                {
                  inherit
                    ((raw {
                      nullkomma.devShell.enable = true;
                      perSystem.nullkomma.devShell.shellHook = ''
                        echo hooked
                        export HOOKED=1
                      '';
                    }).devShells.${pkgs.stdenv.hostPlatform.system}.default
                    )
                    shellHook
                    ;
                }
                ''
                  eval "$shellHook" > stdout 2> stderr
                  test ! -s stdout
                  grep -qx hooked stderr
                  test "$HOOKED" = 1
                  touch $out
                '';
            # Every language server an editor is told to start is in the dev shell.
            language-servers =
              pkgs.runCommandLocal "nullkomma-language-servers"
                { nativeBuildInputs = (perSystem fixtures.md).nullkomma.devShell.packages; }
                ''
                  ${lib.concatMapStrings (s: ''
                    command -v ${lib.escapeShellArg (lib.head s.command)}
                  '') (lib.attrValues (perSystem fixtures.md).nullkomma.editor.languageServers)}
                  touch $out
                '';
            file-updates =
              let
                at = version: task fileVersions.${version};
              in
              pkgs.runCommandLocal "nullkomma-file-updates" { nativeBuildInputs = [ pkgs.git ]; } ''
                mkdir project
                cd project
                git init --quiet
                # Without the git plugin, the project has to ignore generated files itself.
                printf mine > generated.txt
                if output="$(${at "old" "generate-files"} 2>&1)"; then
                  echo "A file Git does not ignore was overwritten" >&2
                  exit 1
                fi
                test "$(cat generated.txt)" = mine
                grep -qF 'Add them to .gitignore' <<<"$output"
                rm generated.txt
                echo '*generated.txt' > .git/info/exclude
                ${at "old" "write-files"}
                # Runs that change nothing print nothing.
                test "$(${at "old" "write-files"} | wc -l)" -eq 0
                ${at "old" "generate-files"}
                grep -q 'Generated by nullkomma. DO NOT EDIT' generated.txt
                # Unchanged generated files keep their mtime, so e.g. `quarto preview` doesn't re-render them.
                touch -d @0 generated.txt
                ${at "old" "generate-files"}
                test "$(stat -c %Y generated.txt)" = 0
                rm generated.txt
                (${(perSystem fileVersions.old).nullkomma.devShell.shellHook})
                test -f generated.txt
                printf 'project edit' > source.txt
                printf 'local edit' > generated.txt
                printf 'Project notes.\n\n%s\n' "$(cat notes.md)" > notes.md
                git add notes.md
                ${at "new" "write-files"}
                test "$(cat source.txt)" = 'project edit'
                test "$(cat notes.md)" = 'Project notes.'
                ${at "new" "generate-files"} < /dev/null
                grep -q 'DO NOT EDIT' generated.txt
                test ! -e stale-generated.txt
                mkdir ../unknown
                cd ../unknown
                git init --quiet
                echo '*generated.txt' > .git/info/exclude
                printf 'preexisting' > source.txt
                printf 'preexisting\n' > notes.md
                ${at "old" "write-files"}
                test "$(cat source.txt)" = preexisting
                test "$(head -n 1 notes.md)" = preexisting
                grep -qxF '<!-- nullkomma:stale:start -->' notes.md
                ln -s source.txt generated.txt
                if ${at "new" "generate-files"}; then
                  echo "Symlink target was not rejected" >&2
                  exit 1
                fi
                test "$(cat source.txt)" = preexisting
                mkdir ../branded
                cd ../branded
                git init --quiet
                ${task fixtures.quarto-branded "write-files"}
                generate="${task fixtures.quarto-branded "generate-files"}"
                mkdir -p _extensions/greeting
                touch _extensions/greeting/stale.lua
                $generate
                test -f _extensions/greeting/greeting.lua
                test ! -e _extensions/greeting/stale.lua
                test -w _extensions/greeting/greeting.lua
                head -n 1 privacy.qmd | grep -q '^<!-- Generated by nullkomma.* -->$'
                $generate
                printf 'own policy' > privacy.qmd
                git add -f privacy.qmd
                if $generate; then
                  echo "Tracked file was overwritten by a generated one" >&2
                  exit 1
                fi
                test "$(cat privacy.qmd)" = 'own policy'
                touch $out
              '';
            file-sections =
              pkgs.runCommandLocal "nullkomma-file-sections" { nativeBuildInputs = [ pkgs.git ]; }
                ''
                  git init --quiet
                  write=${lib.escapeShellArg (task sectioned "write-files")}
                  block='<!-- nullkomma:docs:start -->\nnew\n<!-- nullkomma:docs:end -->'
                  spliced() {
                    printf "$1" > expected
                    cmp expected notes.md
                  }
                  printf '# Notes\n' > notes.md
                  $write
                  spliced "# Notes\n\n$block\n"
                  test "$($write | wc -l)" -eq 0
                  printf 'a\n<!-- nullkomma:docs:start -->\nold\n<!-- nullkomma:docs:end -->\nb\n' > notes.md
                  $write
                  spliced "a\n$block\nb\n"
                  printf '<!-- nullkomma:gone:start -->\nx\n<!-- nullkomma:gone:end -->\n' > notes.md
                  $write
                  spliced "$block\n"
                  # A file from before sections, still as nullkomma wrote it, gets them marked.
                  printf 'new\n' > notes.md
                  $write
                  spliced "$block\n"
                  for malformed in "$block\n$block" '<!-- nullkomma:docs:start -->' '<!-- nullkomma:docs:end -->'; do
                    printf "$malformed\n" > notes.md
                    cp notes.md before
                    if $write 2> stderr; then
                      echo "Malformed markers were accepted" >&2
                      exit 1
                    fi
                    grep -qF 'Malformed nullkomma section markers' stderr
                    cmp before notes.md
                  done
                  touch $out
                '';
            # Upgrades need no state outside the working tree: not in a new clone (#358),
            # nor in worktrees on different versions (#367).
            file-upgrades =
              let
                at = version: task ciVersions.${version} "write-files";
                push = ".github/workflows/push.yml";
              in
              pkgs.runCommandLocal "nullkomma-file-upgrades" { nativeBuildInputs = [ pkgs.git ]; } ''
                export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
                export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
                mkdir project
                cd project
                git init --quiet
                ${at "old"}
                git add -A
                git commit -qm old
                git clone -q . ../clone
                cd ../clone
                ${at "new"}
                grep -qF ci.yml@new ${push}
                test "$(git status --porcelain)" = " M ${push}"
                cat >> ${push} <<'YAML'
                  project:
                    runs-on: ubuntu-latest
                    steps:
                      - run: echo project
                YAML
                ${at "old"}
                grep -qF ci.yml@old ${push}
                grep -qx '  project:' ${push}
                ${lib.getExe pkgs.actionlint} ${push}
                cd ../project
                git worktree add -q ../linked
                (cd ../linked && ${at "new"} && grep -qF ci.yml@new ${push})
                test "$(${at "old"} | wc -l)" -eq 0
                touch $out
              '';
            file-update-task =
              let
                nix = pkgs.writeShellScriptBin "nix" ''
                  printf '%s\n' "$*" >> "$NULLKOMMA_TEST_LOG"
                  case "$*" in
                    "flake update fail") exit 7 ;;
                    "develop --command nk write-files") exit 1 ;;
                  esac
                '';
                update = task fixtures.md "flake-update";
              in
              pkgs.runCommandLocal "nullkomma-file-update-task" { nativeBuildInputs = [ nix ]; } ''
                mkdir project
                cd project
                ${lib.getExe pkgs.git} init -q
                export NULLKOMMA_TEST_LOG="$PWD/calls"
                if ${update} nullkomma; then
                  echo "Update did not propagate file conflicts" >&2
                  exit 1
                fi
                printf '%s\n' 'flake update nullkomma' 'develop --command nk write-files' 'develop --command nk generate-files' > expected
                cmp calls expected
                : > calls
                if ${update} fail; then
                  echo "Failed lock update was not propagated" >&2
                  exit 1
                fi
                printf '%s\n' 'flake update fail' > expected
                cmp calls expected
                : > calls
                mkdir dev
                touch dev/flake.nix
                ${update} || true
                printf '%s\n' 'flake update' 'flake update --flake ./dev' > expected
                head -n 2 calls | cmp - expected
                touch $out
              '';
            # Generated paths stay out of `git status` whether or not `write-files` ran.
            generated-files-ignored =
              let
                at = version: task ignoredVersions.${version};
              in
              pkgs.runCommandLocal "nullkomma-generated-files-ignored" { nativeBuildInputs = [ pkgs.git ]; } ''
                export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
                export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
                ${project (root + "/tests/fixtures/edited-gitignore")}
                clean() {
                  test -z "$(git status --porcelain)" || {
                    git status --porcelain >&2
                    exit 1
                  }
                }

                # With the project's and Quarto's lines, nothing conflicts.
                ${at "old" "write-files"}
                grep -qxF /project-ignored .gitignore
                grep -qxF '/.quarto/' .gitignore
                grep -qxF /generated.txt .gitignore
                test "$(grep -cF .agents .gitignore)" = 0
                git add -A
                git commit -qm "adopt"
                ${at "old" "generate-files"}
                clean
                test "$(cat .agents/skills/kept/.gitignore)" = '*'

                # A project's own skill is not affected by the generated ones beside it.
                mkdir .agents/skills/own
                touch .agents/skills/own/SKILL.md
                git add -A
                test "$(git diff --cached --name-only)" = .agents/skills/own/SKILL.md
                git commit -qm "own skill"

                # `write-files` has not run: a new directory ignores itself,
                # and a new file is refused until the root list covers it.
                fails added.txt ${at "new" "generate-files"}
                test ! -e added.txt
                test -f .agents/skills/after/README.md
                test ! -e .agents/skills/before
                clean
                ${at "new" "write-files"}
                ${at "new" "generate-files"}
                test -f added.txt
                test "$(git status --porcelain)" = ' M .gitignore'
                git add -A
                git commit -qm "upgrade"

                # A directory from before generated directories ignored themselves is rewritten.
                rm .agents/skills/kept/.gitignore
                ${at "new" "generate-files"}
                clean

                # An upgrade in a linked worktree does not hide what the main checkout must prune.
                git reset -q --hard HEAD~1
                ${at "old" "generate-files"}
                git worktree add -q -b upgrade ../linked
                (
                  cd ../linked
                  ${at "old" "generate-files"}
                  echo /added.txt >> .gitignore
                  ${at "new" "generate-files"}
                  test ! -e .agents/skills/before
                  git add -A
                  git commit -qm "upgrade"
                )
                git merge -q --ff-only upgrade
                ${at "new" "generate-files"}
                test ! -e .agents/skills/before
                clean

                touch $out
              '';
            # Renders nullkomma's options the way https://flake.parts does for listed modules.
            options-doc =
              (pkgs.nixosOptionsDoc {
                options = import (root + "/modules/_options.nix") {
                  inherit lib;
                  inherit (inputs) flake-parts nixpkgs;
                  module = nullkomma.flakeModules.default;
                };
                transformOptions =
                  opt:
                  opt
                  // {
                    visible = opt.visible && lib.any (lib.hasPrefix (toString root)) opt.declarations;
                  };
                warningsAreErrors = true;
              }).optionsCommonMark;
          };
        };
    };
}
