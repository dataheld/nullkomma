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
            callFlake
            callFlakeWith
            fixtures
            perSystem
            raw
            summary
            task
            ;
          md = root + "/tests/fixtures/md";
          section = text: builtins.toFile "section.md" text;
          # c runs after a and b, b after a; each appends to `log`.
          dagTasks = lib.mapAttrs (name: task: { description = name; } // task) {
            a = {
              before = [ "b" ];
              command = "echo a >> log";
              watch.paths = [ "flake.nix" ];
            };
            b = {
              command = "echo b >> log";
            };
            c = {
              after = [ "b" ];
              command = ''echo c "$@" >> log'';
              watch.paths = [ "missing" ];
            };
            broken.command = "exit 3";
            d = {
              after = [ "broken" ];
              command = "echo d >> log";
            };
          };
          workflow = raw {
            imports = [
              {
                perSystem.nullkomma.tasks.artifact.command = lib.mkAfter ''
                  printf 'shared extension\n' > "$destination/extension"
                '';
              }
            ];
            perSystem.nullkomma.tasks = lib.mapAttrs (_: task: { working_dir = ""; } // task) (
              dagTasks
              // {
                artifact = {
                  after = [
                    "a"
                    "c"
                  ];
                  output = "artifact";
                  sandboxArgs = [ "sandbox value" ];
                  command = ''
                    test -f README.md
                    destination="''${NULLKOMMA_OUTPUT:-artifact}"
                    mkdir -p "$destination"
                    cp log "$destination/log"
                    printf '%s\n' "$@" > "$destination/args"
                  '';
                  process = {
                    environment.WORKFLOW = "native-up-settings";
                    shutdown.signal = 15;
                  };
                };
              }
            );
          };
          watched = raw {
            perSystem.nullkomma.tasks.prepare = {
              command = ":";
              watch.manifest = pkgs.writeText "broad-inputs.txt" ".\n";
              watch.outputs = [ "/prepared" ];
              watch.ignore = [ "/local-ignore" ];
            };
            perSystem.nullkomma.tasks.generate = {
              after = [ "prepare" ];
              working_dir = "";
              watch = {
                manifest = pkgs.writeText "inputs.txt" "input\n";
                outputs = [
                  "/output"
                  "/output/**"
                  "/other-output"
                  "/other-output/**"
                ];
              };
              command = ''
                echo started >> "$OBSERVED"
                while [[ -e "$HOLD" ]]; do sleep 0.05; done
                test "$(cat input)" != broken
                destination="$(cat destination)"
                mkdir -p "$destination"
                cat input > "$destination/result"
                echo finished >> "$OBSERVED"
              '';
              process.watch = {
                paths = [ "input" ];
                ignore = [ "/process-ignore" ];
              };
            };
            perSystem.nullkomma.tasks.unrelated = {
              command = ":";
              watch = {
                paths = [ "input" ];
                contentPaths = [ "content-inputs" ];
                outputs = [ "/external-output" ];
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
                "untouched.txt".text = version;
                "generated.txt" = {
                  text = version;
                  mode = "generated";
                  commentPrefix = "#";
                };
              }
              # Declared only by the old version, so the new one prunes them.
              // lib.optionalAttrs (version == "old") {
                "stale.txt".text = version;
                "edited.txt".text = version;
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
                  })).nullkomma.files;
              in
              {
                expr = {
                  enabled = lib.mapAttrs (_: f: {
                    inherit (f) mode directory;
                    sections = lib.attrNames f.sections;
                  }) (files true);
                  disabled = files false;
                };
                expected = {
                  enabled = {
                    "AGENTS.md" = {
                      mode = "source";
                      directory = false;
                      sections = [ "agents" ];
                    };
                    ".agents/skills/demo" = {
                      mode = "generated";
                      directory = true;
                      sections = [ ];
                    };
                    ".agents/skills/nk-resolve-file-conflicts" = {
                      mode = "generated";
                      directory = true;
                      sections = [ ];
                    };
                  };
                  disabled = { };
                };
              };
            testAllPluginsDisabledIsBareFramework = {
              expr = map summary [
                (raw { })
                (raw { imports = lib.attrValues plugins; })
                (callFlakeWith {
                  nullkomma = lib.genAttrs (lib.attrNames plugins ++ [ "devShell" ]) (_: {
                    enable = false;
                  });
                } md)
              ];
              expected = lib.replicate 3 {
                files = [ ];
                tools = [
                  "nk-generate-files"
                  "nk-write-files"
                  "treefmt"
                  "tasks"
                  "treefmt"
                ];
                formatters = [ ];
                tasks = [
                  "nk-generate-files"
                  "nk-write-files"
                  "treefmt"
                ];
                checks = [ "treefmt" ];
                shells = [ ];
                editor = {
                  formatter = [
                    "treefmt"
                    "--stdin"
                    "{file}"
                  ];
                  languageServers = { };
                  vscode = {
                    extensions = [ "ibecker.treefmt-vscode" ];
                    settings."editor.defaultFormatter" = "ibecker.treefmt-vscode";
                  };
                };
              };
            };
            testChecksBecomeTaskAndCheck = {
              expr = {
                inherit
                  (summary (raw {
                    perSystem.nullkomma.checks.custom.command = "true";
                  }))
                  tasks
                  checks
                  ;
              };
              expected = {
                tasks = [
                  "nk-check"
                  "nk-generate-files"
                  "nk-write-files"
                  "treefmt"
                ];
                checks = [
                  "custom"
                  "treefmt"
                ];
              };
            };
            testConsumersCustomizeDefaults =
              let
                customized = perSystem (
                  callFlakeWith {
                    perSystem =
                      { pkgs, ... }:
                      {
                        nullkomma.editor.vscode.settings."nix.serverPath" = "project-nixd";
                        nullkomma.devShell.packages = [ pkgs.hello ];
                        treefmt.programs.deadnix.enable = false;
                        treefmt.programs.typos.enable = true;
                      };
                  } md
                );
              in
              {
                expr = {
                  package = lib.elem pkgs.hello customized.nullkomma.devShell.packages;
                  disabled = customized.treefmt.programs.deadnix.enable;
                  enabled = customized.treefmt.programs.typos.enable;
                  setting = customized.nullkomma.editor.vscode.settings."nix.serverPath";
                };
                expected = {
                  package = true;
                  disabled = false;
                  enabled = true;
                  setting = "project-nixd";
                };
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
            testFileSections = {
              expr =
                let
                  splice = import (root + "/modules/core/_sections.nix") { inherit lib; } {
                    commentPrefix = "<!--";
                    commentSuffix = " -->";
                    sections.docs = "new\n";
                  };
                  block = "<!-- nullkomma:docs:start -->\nnew\n<!-- nullkomma:docs:end -->\n";
                  appended = splice "# Notes\n";
                in
                {
                  inherit appended;
                  idempotent = splice appended == appended;
                  inPlace = splice "a\n<!-- nullkomma:docs:start -->\nold\n<!-- nullkomma:docs:end -->\nb\n";
                  undeclared = splice "<!-- nullkomma:gone:start -->\nx\n<!-- nullkomma:gone:end -->\n";
                  malformed = map (text: (builtins.tryEval (splice text)).success) [
                    "<!-- nullkomma:docs:start -->\n"
                    "<!-- nullkomma:docs:end -->\n"
                    (block + block)
                  ];
                  inherit block;
                };
              expected = rec {
                block = "<!-- nullkomma:docs:start -->\nnew\n<!-- nullkomma:docs:end -->\n";
                appended = "# Notes\n\n" + block;
                idempotent = true;
                inPlace = "a\n" + block + "b\n";
                undeclared = block;
                malformed = [
                  false
                  false
                  false
                ];
              };
            };
            testGeneratedCommandCollisions = {
              expr =
                map
                  (
                    module:
                    let
                      flake = perSystem (raw {
                        nullkomma.devShell.enable = true;
                        perSystem = module;
                      });
                    in
                    {
                      runner = (builtins.tryEval flake.taskRunners.default.drvPath).success;
                      shell = (builtins.tryEval flake.devShells.default.drvPath).success;
                    }
                  )
                  [
                    {
                      processTrees = lib.mkForce { };
                      nullkomma.tasks = lib.genAttrs [ "demo" "nk-demo" ] (_: {
                        command = ":";
                        watch.paths = [ "flake.nix" ];
                      });
                    }
                    {
                      nullkomma.tasks = lib.genAttrs [ "demo" "nk-demo" ] (_: {
                        command = ":";
                        process = { };
                      });
                    }
                    {
                      nullkomma.tasks.demo.command = ":";
                      nullkomma.processTrees = lib.genAttrs [ "demo" "nk-demo" ] (_: {
                        description = "Demo";
                        tasks = [ "demo" ];
                      });
                    }
                    {
                      nullkomma.tasks = {
                        demo = {
                          command = ":";
                          watch.paths = [ "flake.nix" ];
                        };
                        nk-watch-demo.command = ":";
                      };
                    }
                    {
                      nullkomma.tasks = {
                        demo = {
                          command = ":";
                          process = { };
                        };
                        nk-pc-up-demo.command = ":";
                      };
                    }
                  ];
              expected = lib.replicate 5 {
                runner = false;
                shell = false;
              };
            };
            testGitignoreContainsPluginPatternsAndGeneratedFiles = {
              expr = map (flake: (perSystem flake).nullkomma.files.".gitignore".text) [
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
                  "/.nullkomma/processes/"
                  "/.agents/skills/nk-resolve-file-conflicts"
                  "/.agents/skills/nk-upgrade"
                  "/.nvim.lua"
                  "/.vscode/extensions.json"
                  "/.vscode/settings.json"
                ])
                (lib.concatLines [
                  "result"
                  "result-*"
                  ".direnv/"
                  "/.nullkomma/processes/"
                  "/.agents/skills/nk-resolve-file-conflicts"
                  "/.agents/skills/nk-upgrade"
                  "/.nvim.lua"
                ])
              ];
            };
            testImportTreeSkipsUnderscoresAndNonNix =
              let
                tree = root + "/tests/fixtures/import-tree";
              in
              {
                expr = map (p: lib.removePrefix (toString tree) (toString p)) (
                  import (root + "/lib/import-tree.nix") lib tree
                );
                expected = [
                  "/a.nix"
                  "/sub/b.nix"
                ];
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
            testNativeWatch =
              let
                flake = perSystem (raw {
                  perSystem.nullkomma.tasks.serve = {
                    command = "sleep 1";
                    watch.native = true;
                  };
                });
              in
              {
                expr = {
                  paths = flake.nullkomma.tasks.serve.watch.paths;
                  watch = flake.processTrees.serve.processes.serve.watch;
                  aliases = lib.filter (lib.hasPrefix "nk-watch-") (
                    map lib.getName flake.nullkomma.devShell.packages
                  );
                };
                expected = {
                  paths = [ ];
                  watch = null;
                  aliases = [ ];
                };
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
            testTaskDag =
              let
                flake = perSystem (raw {
                  perSystem.nullkomma = {
                    tasks = dagTasks;
                    processTrees.tree = {
                      description = "Tree";
                      tasks = [ "c" ];
                    };
                  };
                });
              in
              {
                expr = {
                  closure = flake.nullkomma.tasks.c.closure;
                  trees = lib.attrNames flake.processTrees;
                  processes = lib.attrNames flake.processTrees.tree.processes;
                  watches = lib.filter (lib.hasPrefix "nk-watch-") (
                    map lib.getName flake.nullkomma.devShell.packages
                  );
                  downstream = flake.processTrees.tree.processes.b.watch.paths;
                  dependency = flake.processTrees.tree.processes.b.depends_on.a.condition;
                  native = (perSystem workflow).processTrees.artifact.processes.artifact.environment;
                };
                expected = {
                  closure = [
                    "a"
                    "b"
                    "c"
                  ];
                  trees = [
                    "a"
                    "c"
                    "tree"
                  ];
                  processes = [
                    "a"
                    "b"
                    "c"
                  ];
                  # c's own path is missing, but it watches a's inputs too.
                  watches = [
                    "nk-watch-a"
                    "nk-watch-c"
                  ];
                  downstream = [ ".nullkomma/processes/tree/a.ok" ];
                  dependency = "process_completed_successfully";
                  native.WORKFLOW = "native-up-settings";
                };
              };
            testTasksAllHonorsSkip = {
              expr = lib.attrNames (
                lib.filterAttrs (_: t: !(t.skip or false)) (perSystem fixtures.md).nullkomma.tasks
              );
              expected = [
                "flake-checker"
                "nk-check"
                "treefmt"
              ];
            };
            testTemplatesAreFixtures = {
              expr = lib.mapAttrs (_: t: {
                flake = builtins.readFile (t.path + "/flake.nix");
                envrc = builtins.readFile (t.path + "/.envrc");
              }) nullkomma.templates;
              expected = lib.mapAttrs (_: t: {
                flake = builtins.readFile (root + "/tests/fixtures/md/flake.nix");
                envrc = (perSystem (callFlake t.path)).nullkomma.files.".envrc".text;
              }) nullkomma.templates;
            };
            testWatchOutputExclusions =
              let
                processes = (perSystem watched).processTrees.generate.processes;
                outputs = [
                  "/prepared"
                  "/external-output"
                ]
                ++ (perSystem watched).nullkomma.tasks.generate.watch.outputs;
              in
              {
                expr = {
                  graph = lib.all (process: lib.all (path: lib.elem path process.watch.ignore) outputs) (
                    lib.attrValues processes
                  );
                  local = lib.elem "/local-ignore" processes.prepare.watch.ignore;
                  override = lib.elem "/process-ignore" processes.generate.watch.ignore;
                  paths = processes.generate.watch.paths;
                };
                expected = {
                  graph = true;
                  local = true;
                  override = true;
                  paths = [ "input" ];
                };
              };
            # keep-sorted end
          };
          checks = {
            process-task-failure =
              let
                flake = perSystem (raw {
                  perSystem.nullkomma.tasks.fail = {
                    process = { };
                    command = "exit 42";
                  };
                });
                command = flake.processTrees.fail.processes.fail.command;
              in
              pkgs.runCommand "nullkomma-process-task-failure"
                {
                  nativeBuildInputs = [
                    pkgs.bash
                    pkgs.coreutils
                  ];
                }
                ''
                  ${harness.project md}
                  export NULLKOMMA_ROOT="$PWD"
                  mkdir -p .nullkomma/processes/fail
                  stamp=.nullkomma/processes/fail/fail.ok
                  touch -d @1 "$stamp"
                  before="$(stat -c %Y "$stamp")"
                  if bash -c ${lib.escapeShellArg command}; then
                    echo "Failed process task returned success" >&2
                    exit 1
                  fi
                  [[ "$(stat -c %Y "$stamp")" == "$before" ]]
                  touch "$out"
                '';
            process-socket =
              let
                flake = raw {
                  perSystem.nullkomma.tasks.socket = {
                    process = { };
                    command = ''
                      test -S "$PC_SOCKET_PATH"
                      cp -r . "$TMPDIR/copied"
                      touch "$TMPDIR/copied-ok"
                    '';
                  };
                };
              in
              pkgs.runCommand "nullkomma-process-socket" { nativeBuildInputs = [ pkgs.git ]; } ''
                ${harness.project md}
                git init -q
                export PC_DISABLE_TUI=1
                ${lib.getExe (perSystem flake).processTrees.socket}
                test -f "$TMPDIR/copied-ok"
                touch "$out"
              '';
            workflow-watch =
              pkgs.runCommand "nullkomma-workflow-watch"
                {
                  nativeBuildInputs = [
                    pkgs.git
                    pkgs.python3
                  ];
                }
                ''
                  mkdir repo
                  cd repo
                  git init --quiet
                  printf 'ignored-input\n' > .gitignore
                  printf 'first\n' > input
                  printf 'output\n' > destination
                  mkdir content-inputs
                  printf 'saved\n' > content-inputs/saved
                  export OBSERVED="$TMPDIR/observed" HOLD="$TMPDIR/hold"
                  python ${./_watch.test.py} \
                    ${
                      lib.getExe (
                        lib.findFirst (p: lib.getName p == "nk-watch-generate") null
                          (perSystem watched).nullkomma.devShell.packages
                      )
                    } \
                    ${lib.getExe (import ./_watch.nix { inherit lib pkgs; })} \
                    || { cat "$TMPDIR/watcher.log"; exit 1; }
                  touch "$out"
                '';
            task-dag =
              let
                flake = raw { perSystem.nullkomma.tasks = dagTasks; };
              in
              pkgs.runCommand "nullkomma-task-dag" { } ''
                ${task flake "c"} arg
                printf 'a\nb\nc arg\n' | diff - log
                rm log
                if ${task flake "d"}; then exit 1; fi
                [[ ! -e log ]]
                ${lib.getExe (perSystem flake).taskRunners.default} c
                printf 'a\nb\nc\n' | diff - log
                rm log
                if ${lib.getExe (perSystem flake).taskRunners.default} d; then exit 1; fi
                [[ ! -e log ]]
                mkdir project
                cd project
                cp ${md + "/README.md"} README.md
                ${lib.getExe pkgs.git} init --quiet
                mkdir nested && cd nested
                ${task workflow "artifact"} 'local value'
                cd ..
                printf 'a\nb\nc\n' | diff - artifact/log
                printf 'local value\n' | diff - artifact/args
                cmp artifact/log ${(perSystem workflow).packages.artifact}/log
                cmp artifact/extension ${(perSystem workflow).packages.artifact}/extension
                grep -qxF 'shared extension' artifact/extension
                test -x ${lib.getExe (perSystem workflow).processTrees.artifact}
                printf 'sandbox value\n' | diff - ${(perSystem workflow).packages.artifact}/args
                touch $out
              '';
            task-menu =
              let
                flake = raw {
                  perSystem.nullkomma.checks.custom.command = "echo custom-check";
                  perSystem.processTrees.server = pkgs.symlinkJoin {
                    name = "custom-server";
                    paths = [ (pkgs.writeShellScriptBin "custom-server" "echo native-server") ];
                  };
                };
                runner = (perSystem flake).taskRunners.default;
              in
              pkgs.runCommand "nullkomma-task-menu" { } ''
                ${lib.getExe pkgs.git} init -q
                ${lib.getExe runner} > menu
                grep -qF 'nk-check <name> [args]: custom' menu
                grep -qF "for arguments, run the listed command directly" menu
                ${lib.getExe runner} nk-check > checked
                grep -qF custom-check checked
                ${lib.getExe runner} nk-pc-up-server > process
                grep -qF native-server process
                ${
                  lib.getExe (
                    lib.findFirst (p: lib.getName p == "nk-pc-up-server") null
                      (perSystem flake).nullkomma.devShell.packages
                  )
                } > process
                grep -qxF native-server process
                touch flake.nix
                export HOME="$TMPDIR"
                ${lib.getExe runner} all > checked-all || { cat checked-all; exit 1; }
                grep -qF custom-check checked-all
                grep -qF 'formatted' checked-all
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
                ${at "old" "nk-write-files"}
                ${at "old" "nk-generate-files"}
                grep -q 'Generated by nullkomma. DO NOT EDIT' generated.txt
                # Unchanged generated files keep their mtime, so e.g. `quarto preview` doesn't re-render them.
                touch -d @0 generated.txt
                ${at "old" "nk-generate-files"}
                test "$(stat -c %Y generated.txt)" = 0
                # Entering the dev shell regenerates only when the generated files changed.
                rm generated.txt
                (${(perSystem fileVersions.old).nullkomma.devShell.shellHook})
                test -f generated.txt
                rm generated.txt
                (${(perSystem fileVersions.old).nullkomma.devShell.shellHook})
                test ! -e generated.txt
                ${at "old" "nk-generate-files"}
                printf 'project edit' > source.txt
                printf 'local edit' > generated.txt
                printf 'project edit' > edited.txt
                printf 'Project notes.\n\n%s\n' "$(cat notes.md)" > notes.md
                if ${at "new" "nk-write-files"}; then
                  echo "Edited source-of-truth file unexpectedly overwritten" >&2
                  exit 1
                fi
                test ! -e stale.txt
                test ! -e .git/nullkomma/files/base/stale.txt
                test "$(cat edited.txt)" = 'project edit'
                test "$(cat notes.md)" = 'Project notes.'
                test "$(cat source.txt)" = 'project edit'
                test "$(cat untouched.txt)" = new
                test "$(cat .git/nullkomma/files/base/source.txt)" = old
                test "$(cat .git/nullkomma/files/incoming/source.txt)" = new
                ${at "new" "nk-generate-files"} < /dev/null
                grep -q 'DO NOT EDIT' generated.txt
                test ! -e stale-generated.txt
                ${at "new" "nk-write-files"} --accept source.txt
                ${at "new" "nk-write-files"}
                test "$(cat source.txt)" = 'project edit'
                test "$(cat .git/nullkomma/files/base/source.txt)" = new
                test ! -f .git/nullkomma/files/incoming/source.txt
                mkdir ../unknown
                cd ../unknown
                git init --quiet
                printf 'preexisting' > source.txt
                if ${at "new" "nk-write-files"}; then
                  echo "Unknown source-of-truth file was not reported" >&2
                  exit 1
                fi
                test "$(cat source.txt)" = preexisting
                test ! -f .git/nullkomma/files/base/source.txt
                ln -s source.txt generated.txt
                if ${at "new" "nk-generate-files"}; then
                  echo "Symlink target was not rejected" >&2
                  exit 1
                fi
                test "$(cat source.txt)" = preexisting
                mkdir ../branded
                cd ../branded
                git init --quiet
                generate=${task fixtures.quarto-branded "nk-generate-files"}
                mkdir -p _extensions/greeting
                touch _extensions/greeting/stale.lua
                $generate
                test -f _extensions/greeting/greeting.lua
                test ! -e _extensions/greeting/stale.lua
                test -w _extensions/greeting/greeting.lua
                head -n 1 privacy.qmd | grep -q '^<!-- Generated by nullkomma.* -->$'
                $generate
                printf 'own policy' > privacy.qmd
                git add privacy.qmd
                if $generate; then
                  echo "Tracked file was overwritten by a generated one" >&2
                  exit 1
                fi
                test "$(cat privacy.qmd)" = 'own policy'
                touch $out
              '';
            file-update-task =
              let
                nix = pkgs.writeShellScriptBin "nix" ''
                  printf '%s\n' "$*" >> "$NULLKOMMA_TEST_LOG"
                  case "$*" in
                    "flake update fail") exit 7 ;;
                    "develop --command nk-write-files") exit 1 ;;
                  esac
                '';
                update = task fixtures.md "nk-update";
              in
              pkgs.runCommandLocal "nullkomma-file-update-task" { nativeBuildInputs = [ nix ]; } ''
                export NULLKOMMA_TEST_LOG="$PWD/calls"
                if ${update} nullkomma; then
                  echo "Update did not propagate file conflicts" >&2
                  exit 1
                fi
                printf '%s\n' 'flake update nullkomma' 'develop --command nk-write-files' 'develop --command nk-generate-files' > expected
                cmp calls expected
                : > calls
                if ${update} fail; then
                  echo "Failed lock update was not propagated" >&2
                  exit 1
                fi
                printf '%s\n' 'flake update fail' > expected
                cmp calls expected
                touch $out
              '';
            # Renders nullkomma's options the way https://flake.parts does for listed modules:
            # without `pkgs`, `systems` or `self`, so computed defaults need a `defaultText`.
            options-doc =
              let
                unavailable =
                  what: throw "${what} is not available when rendering option docs; add a `defaultText`.";
                docs =
                  inputs.flake-parts.lib.evalFlakeModule
                    {
                      inputs = {
                        inherit (inputs) nixpkgs;
                        self.outPath = unavailable "`self.outPath`";
                      };
                    }
                    {
                      imports = [
                        nullkomma.flakeModules.default
                        (
                          { flake-parts-lib, ... }:
                          {
                            options.perSystem = flake-parts-lib.mkPerSystemOption {
                              _module.args.pkgs = lib.mapAttrs (name: _: unavailable "`pkgs.${name}`") pkgs // {
                                _type = "pkgs";
                                inherit lib;
                                inherit (pkgs) formats;
                              };
                            };
                          }
                        )
                      ];
                      systems = [ (unavailable "`systems`") ];
                    };
              in
              (pkgs.nixosOptionsDoc {
                inherit (docs) options;
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
