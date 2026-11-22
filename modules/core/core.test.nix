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
            summary
            task
            ;
          template = root + "/templates/default";
          # Renders nullkomma's options the way https://flake.parts does for listed modules.
          optionsDoc = pkgs.nixosOptionsDoc {
            options = import (root + "/modules/_options.nix") {
              inherit lib;
              inherit (inputs) flake-parts nixpkgs;
              module = nullkomma.flakeModules.default;
            };
            transformOptions =
              opt:
              let
                declarations = map (lib.removePrefix "${toString root}/") (
                  lib.filter (lib.hasPrefix "${toString root}/") opt.declarations
                );
              in
              opt
              // {
                inherit declarations;
                visible = opt.visible && declarations != [ ];
              };
            warningsAreErrors = true;
          };
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
              quiet = {
                command = "process-compose version 2> stderr";
                disabled = true;
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
          # A check recording whether formatting has finished.
          formatting = raw {
            perSystem.process-compose.dev.settings.processes = {
              treefmt.command = lib.mkForce "sleep 1; touch formatted";
              probe = {
                command = "if test -e formatted; then echo after; else echo before; fi >> order";
                disabled = true;
              };
              check.depends_on.probe.condition = "process_completed_successfully";
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
          importTree = root + "/tests/fixtures/import-tree";
          fileVersions = lib.genAttrs [ "old" "new" ] (
            version:
            raw {
              perSystem.nullkomma.links = {
                "linked.txt".text = version;
                # A directory with a subdirectory; the new version lacks one file.
                "dir/linked".source =
                  if version == "old" then
                    importTree
                  else
                    builtins.path {
                      path = importTree;
                      name = "import-tree";
                      filter = path: _: baseNameOf path != "readme.txt";
                    };
              }
              // (
                if version == "old" then
                  {
                    # Declared only by the old version, so the new one prunes them unless they are the project's.
                    "stale.txt".text = version;
                    "stale/linked".source = importTree;
                    "own.txt".text = version;
                    "blocked/inner".text = version;
                    # Change from file to directory, and back.
                    "morph".text = version;
                    "shape/inner".text = version;
                  }
                else
                  {
                    "morph/inner".text = version;
                    "shape".text = version;
                  }
              );
            }
          );
          # A flake in `nested/`, below its repository's root.
          nestedFiles =
            inputs.flake-parts.lib.mkFlake
              {
                inputs.self = {
                  outPath = "/source/nested";
                  sourceInfo.outPath = "/source";
                };
              }
              {
                imports = [
                  config.mkFlake
                  nullkomma.flakeModules.framework
                ];
                debug = true;
                perSystem.nullkomma = {
                  links."linked.txt".text = "nested";
                  files."notes.md".text = "nested";
                };
              };
          projectFiles = raw {
            perSystem.nullkomma.files."docs/notes.md".text = "# Notes\nrequired\n";
          };
          ignored = raw {
            imports = [ plugins.git ];
            nullkomma.git.enable = true;
            perSystem.nullkomma.links = {
              "linked.txt".text = "linked";
              ".agents/skills/linked".source = template;
            };
          };
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
            testAgentsPluginLinksSkillsAndServers =
              let
                cfg =
                  enable:
                  (perSystem (raw {
                    imports = [ plugins.agents ];
                    nullkomma.agents = {
                      inherit enable;
                      skills.demo = template;
                    };
                    perSystem.nullkomma.agents.mcpServers.demo = {
                      type = "http";
                      url = "https://example.com/mcp";
                    };
                  })).nullkomma;
              in
              {
                expr = {
                  links = lib.attrNames (cfg true).links;
                  files = lib.attrNames (cfg true).files;
                  servers = lib.attrNames (builtins.fromJSON (cfg true).links.".mcp.json".text).mcpServers;
                  disabled = { inherit (cfg false) links files; };
                };
                expected = {
                  links = [
                    ".agents/skills/demo"
                    ".agents/skills/nk-audit-output"
                    ".mcp.json"
                  ];
                  files = [ "AGENTS.md" ];
                  servers = [
                    "demo"
                    "nullkomma"
                  ];
                  disabled = {
                    links = { };
                    files = { };
                  };
                };
              };
            testAllPluginsDisabledIsBareFramework = {
              expr = map summary [
                (raw { imports = lib.attrValues plugins; })
                (callFlakeWith {
                  nullkomma = lib.genAttrs (lib.attrNames plugins ++ [ "devShell" ]) (_: {
                    enable = false;
                  });
                } template)
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
                  } template
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
                    (callFlakeWith dev template).outputs
                    (callFlakeWith (dev // { nullkomma.nix.enable = false; }) template).outputs
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
                lib.filterAttrs (_: p: p.disabled != true) (perSystem fixtures.template).processTrees.dev.processes
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
                    imports = [ { nullkomma.cloudflareSite.worker = "fixture-site"; } ];
                    nullkomma.${name}.enable = !fixtures.template.debug.config.nullkomma.${name}.enable;
                  } (if name == "r" then root + "/tests/fixtures/r" else template)
                ) == summary fixtures.template
              ) (lib.attrNames plugins);
              expected = [ ];
            };
            testGitignoreRequiresPluginPatternsAndLinks = {
              expr = map (flake: (perSystem flake).nullkomma.files.".gitignore".text) [
                fixtures.template
                (callFlakeWith {
                  perSystem.nullkomma.links = {
                    ".vscode/settings.json".enable = false;
                    ".vscode/extensions.json".enable = false;
                  };
                } template)
              ];
              expected = [
                (lib.concatLines [
                  "result"
                  "result-*"
                  ".direnv/"
                  "/.nullkomma/gcroots/"
                  "/.agents/skills/nk-audit-output"
                  "/.agents/skills/nk-upgrade"
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
                  "/.agents/skills/nk-audit-output"
                  "/.agents/skills/nk-upgrade"
                  "/.mcp.json"
                  "/.nvim.lua"
                  "/.vscode/mcp.json"
                ])
              ];
            };
            testImportTreeSkipsUnderscoresAndNonNix = {
              expr = {
                found = map (p: lib.removePrefix (toString importTree) (toString p)) (
                  nullkomma.lib.importTree importTree
                );
                missing = nullkomma.lib.importTree (importTree + "/missing");
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
                    } template
                  )
                );
                expected = normalize (summary fixtures.template);
              };
            testOptionsDocHasNoStorePaths = {
              expr = lib.hasInfix builtins.storeDir (builtins.toJSON optionsDoc.optionsNix);
              expected = false;
            };
            testPluginsAddMcpServers =
              let
                servers = flake: lib.attrNames (perSystem flake).nullkomma.agents.mcpServers;
              in
              {
                expr = map servers [
                  fixtures.template
                  fixtures.cloudflare
                  fixtures.quarto
                  (callFlakeWith { nullkomma.quarto.enable = true; } (root + "/tests/fixtures/r-shiny"))
                  (callFlakeWith {
                    nullkomma.quarto.enable = true;
                    nullkomma.agents.browser.enable = false;
                  } (root + "/tests/fixtures/r-shiny"))
                  (callFlakeWith { nullkomma.opentofu.enable = true; } template)
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
                  [
                    "nullkomma"
                    "r"
                  ]
                  [
                    "nullkomma"
                    "opentofu"
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
                    })).nullkomma.links.".mcp.json".text
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
              expr = lib.attrNames (perSystem fixtures.template).processTrees.dev.processes.all.depends_on;
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
            # keep-sorted end
          };
          checks = {
            tasks =
              let
                inherit ((perSystem contract).nullkomma) devShell sandbox;
                tasks = lib.getExe (perSystem contract).taskRunners.default;
                sandboxed = sandbox {
                  process = "b";
                  args = [ "sandboxed value" ];
                  output = "log";
                };
              in
              pkgs.runCommand "nullkomma-tasks" (devShell.env // { nativeBuildInputs = devShell.packages; }) ''
                ${harness.project template}
                export HOME="$TMPDIR" PC_LOG_FILE="$TMPDIR/pc.log"
                logs=(mcp.out preview.out "$PC_LOG_FILE" mcp.log)
                rewatched() { [ "$(wc -l < watched)" -eq 2 ]; }
                answered() { [ "$(grep -cE '"id":[0-9]+,' mcp.out)" -eq 5 ]; }
                ${tasks} > menu
                grep -qF '[demo]' menu
                ${tasks} b 'local value'
                printf 'a\nb local value\n' | diff - log
                # The dev shell's `process-compose` runs in the Git root.
                mkdir sub
                (
                  ${devShell.shellHook}
                  cd sub && process-compose up b -t=false
                )
                printf 'a\nb local value\na\nb\n' | diff - log
                if ${tasks} broken; then exit 1; fi
                printf 'a\nb sandboxed value\n' | diff - ${sandboxed}
                test ! -s ${
                  sandbox {
                    process = "quiet";
                    output = "stderr";
                  }
                }
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
              ${harness.project template}
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
            # `all` formats before any check reads the tree; `check` doesn't format.
            all-formats-first = pkgs.runCommand "nullkomma-all-formats-first" { } ''
              ${harness.project template}
              ${task formatting "check"}
              test ! -e formatted
              ${task formatting "all"}
              printf 'before\nafter\n' | diff - order
              touch $out
            '';
            scratch = pkgs.runCommand "nullkomma-scratch" { } ''
              ${harness.project template}
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
              ${harness.project template}
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
                    (perSystem fixtures.template).treefmt.build.wrapper
                  ];
                }
                ''
                  ${harness.project template}
                  HOME=$TMPDIR nvim --clean -l ${pkgs.writeText "check.lua" ''
                    dofile("${(perSystem fixtures.template).nullkomma.links.".nvim.lua".source}")
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
                        } template
                      )).nullkomma.links.".nvim.lua".source
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
                { nativeBuildInputs = (perSystem fixtures.template).nullkomma.devShell.packages; }
                ''
                  ${lib.concatMapStrings (s: ''
                    command -v ${lib.escapeShellArg (lib.head s.command)}
                  '') (lib.attrValues (perSystem fixtures.template).nullkomma.editor.languageServers)}
                  touch $out
                '';
            links =
              let
                at = version: task fileVersions.${version} "link-files";
                # Records the garbage collector roots that `link-files` registers when `nix-store` is on the PATH.
                nix-store = pkgs.writeShellScriptBin "nix-store" ''
                  echo "$*" >> "$NULLKOMMA_TEST_ROOTS"
                  ln -sfn "$4" "$2"
                '';
              in
              pkgs.runCommandLocal "nullkomma-links-test" { nativeBuildInputs = [ pkgs.git ]; } ''
                ${project template}
                mkdir ../outside
                export NULLKOMMA_TEST_ROOTS="$PWD/../roots" PATH="${nix-store}/bin:$PATH"
                # Git must ignore links and their record first, or they could be committed.
                fails /linked.txt ${at "old"}
                grep -qx /.nullkomma/gcroots/ "$TMPDIR/failure.log"
                test ! -e linked.txt
                test ! -e .nullkomma
                printf '%s\n' '*.txt' /dir/ /stale/ /blocked /morph /shape .nullkomma/ > .git/info/exclude
                printf mine > own.txt
                printf mine > blocked
                fails "own.txt, as the project has its own" ${at "old"}
                grep -qF "blocked/inner, as blocked is not a real directory" "$TMPDIR/failure.log"
                test "$(cat own.txt)" = mine
                test "$(cat linked.txt)" = old
                test -L dir/linked/sub/b.nix
                test ! -L dir/linked
                test ! -L dir/linked/sub
                [[ "$(readlink linked.txt)" == /nix/store/*-nullkomma-links/linked.txt ]]
                previous=.nullkomma/gcroots/links
                test "$(readlink $previous)/linked.txt" = "$(readlink linked.txt)"
                grep -qxF -- "--add-root $previous --realise $(readlink $previous)" ../roots
                rm own.txt blocked
                ${at "old"} > out
                test "$(grep -c 'linked ' out)" = 2
                # Unchanged links stay as they are, so watchers such as `quarto preview` see no change.
                touch -h -d @0 linked.txt
                ${at "old"} > out
                test "$(wc -l < out)" = 0
                test "$(stat -c %Y linked.txt)" = 0
                git add -f linked.txt
                fails "linked.txt, as Git tracks it" ${at "old"}
                git rm -q --cached linked.txt
                rm linked.txt
                (${(perSystem fileVersions.old).nullkomma.devShell.shellHook})
                test "$(cat linked.txt)" = old
                # Each worktree has its own links and record of them, so an upgrade in one
                # leaves another's links in place, to prune on its own upgrade (#367).
                git worktree add -q --orphan -b linked ../linked
                (cd ../linked && ${at "old"} && ${at "new"})
                test ! -e ../linked/stale.txt
                test "$(cat stale.txt)" = old
                # An upgrade follows the new bundle, and prunes only links into the old one.
                rm own.txt
                printf mine > own.txt
                printf mine > dir/linked/sub/own.txt
                ${at "new"} > out
                test "$(cat linked.txt)" = new
                test "$(cat own.txt)" = mine
                test "$(cat dir/linked/sub/own.txt)" = mine
                test ! -e stale.txt
                test ! -e stale
                test ! -e blocked
                test ! -e dir/linked/readme.txt
                grep -qF "removed dir/linked/readme.txt" out
                test "$(grep -cF dir/linked/a.nix out)" = 0
                test -L dir/linked/a.nix
                test -L dir/linked/sub/b.nix
                test "$(cat morph/inner)" = new
                test "$(cat shape)" = new
                test "$(readlink $previous)/linked.txt" = "$(readlink linked.txt)"
                rm -r dir
                ln -s ../outside dir
                fails "as dir is not a real directory" ${at "new"}
                test -z "$(ls ../outside)"
                touch $out
              '';
            # nullkomma creates missing project files and checks the rest; it replaces one only on `--overwrite`.
            required-lines =
              let
                check = task projectFiles "project-files";
                write = task projectFiles "write-files";
              in
              pkgs.runCommandLocal "nullkomma-required-lines" { nativeBuildInputs = [ pkgs.git ]; } ''
                ${project template}
                fails "docs/notes.md is missing" ${check}
                ${write}
                grep -qx required docs/notes.md
                ${check}
                ${write} > out
                test "$(wc -l < out)" = 0
                printf 'own\n' > docs/notes.md
                ${write}
                test "$(cat docs/notes.md)" = own
                fails "lacks lines nullkomma requires" ${check}
                grep -qx required "$TMPDIR/failure.log"
                printf 'own\n# Notes\n\nrequired\n' > docs/notes.md
                ${check}
                # `--overwrite` replaces named files that lack lines, if Git can restore what they had.
                fails Usage ${write} --overwrite
                ${write} --overwrite docs/notes.md > out
                grep -qF "kept docs/notes.md" out
                printf 'own\n' > docs/notes.md
                fails "docs/notes.md, as Git could not restore it" ${write} --overwrite docs/notes.md
                git add docs/notes.md
                git -c user.name=test -c user.email=test@example.com commit -qm notes
                printf 'edit\n' >> docs/notes.md
                fails "docs/notes.md, as Git could not restore it" ${write} --overwrite docs/notes.md
                test "$(tail -n 1 docs/notes.md)" = edit
                git checkout -q docs/notes.md
                fails "flake.nix, as nullkomma requires no lines in it" ${write} --overwrite docs/notes.md flake.nix
                ${check}
                git diff HEAD -- docs/notes.md | grep -qx -- -own
                touch $out
              '';
            # A flake below its repository's root works only in its own directory.
            nested-project =
              pkgs.runCommandLocal "nullkomma-nested-project" { nativeBuildInputs = [ pkgs.git ]; }
                ''
                  git init --quiet
                  printf '%s\n' '*.txt' .nullkomma/ > .git/info/exclude
                  mkdir -p nested/sub
                  cd nested/sub
                  ${task nestedFiles "write-files"}
                  ${task nestedFiles "link-files"}
                  cd ../..
                  grep -qx nested nested/notes.md
                  test "$(cat nested/linked.txt)" = nested
                  test ! -e linked.txt
                  test ! -e notes.md
                  touch $out
                '';
            github-workflow = pkgs.runCommandLocal "nullkomma-github-workflow" { } ''
              ${lib.getExe pkgs.actionlint} ${
                (perSystem (raw {
                  imports = [ plugins.github ];
                  nullkomma.github.enable = true;
                })).nullkomma.files.".github/workflows/push.yml".source
              }
              touch $out
            '';
            flake-update-task =
              let
                nix = pkgs.writeShellScriptBin "nix" ''
                  printf '%s\n' "$*" >> "$NULLKOMMA_TEST_LOG"
                  case "$*" in
                    "flake update --flake . fail") exit 7 ;;
                  esac
                '';
                update = task fixtures.template "flake-update";
                lock =
                  inputs:
                  builtins.toJSON {
                    nodes.root.inputs = lib.genAttrs (lib.splitString " " inputs) lib.id;
                    root = "root";
                    version = 7;
                  };
              in
              pkgs.runCommandLocal "nullkomma-flake-update-task" { nativeBuildInputs = [ nix ]; } ''
                mkdir -p project/dev
                cd project
                ${lib.getExe pkgs.git} init -q
                export NULLKOMMA_TEST_LOG="$PWD/calls"
                called() {
                  printf '%s\n' "$@" | cmp calls -
                  : > calls
                }
                echo '${lock "nullkomma"}' > flake.lock
                ${update} nullkomma
                called 'flake update --flake . nullkomma'

                touch dev/flake.nix
                echo '${lock "brand nullkomma"}' > dev/flake.lock
                ${update} nullkomma brand
                called 'flake update --flake . nullkomma' 'flake update --flake ./dev brand nullkomma'

                if ${update} nullkomma --help 2> error; then
                  echo "Update of an input no flake has succeeded" >&2
                  exit 1
                fi
                grep -qF "'--help'" error
                test ! -s calls

                echo '${lock "fail"}' > flake.lock
                if ${update} fail; then
                  echo "Failed lock update was not propagated" >&2
                  exit 1
                fi
                called 'flake update --flake . fail'

                ${update}
                called 'flake update --flake .' 'flake update --flake ./dev'
                touch $out
              '';
            # Links stay out of `git status`, beside the project's own skills.
            links-ignored =
              pkgs.runCommandLocal "nullkomma-links-ignored" { nativeBuildInputs = [ pkgs.git ]; }
                ''
                  ${project template}
                  fails /.agents/skills/linked ${task ignored "link-files"}
                  ${task ignored "write-files"}
                  git add -A
                  ${task ignored "link-files"}
                  test -z "$(git ls-files --others --exclude-standard)"
                  mkdir .agents/skills/own
                  touch .agents/skills/own/SKILL.md
                  test "$(git ls-files --others --exclude-standard)" = .agents/skills/own/SKILL.md
                  touch $out
                '';
            options-doc = optionsDoc.optionsCommonMark;
          };
        };
    };
}
