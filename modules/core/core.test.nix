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
                disabled = true;
              };
              broken = {
                description = "Broken";
                command = "exit 3";
                disabled = true;
              };
              serve.command = "sleep 60";
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
                  removeAttrs
                    (perSystem (raw {
                      imports = [ plugins.agents ];
                      nullkomma.agents = {
                        inherit enable;
                        skills.demo = md;
                      };
                    })).nullkomma.files
                    [ ".mcp.json" ];
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
                files = [ ".mcp.json" ];
                tools = [
                  "nk"
                  "process-compose"
                  "treefmt"
                ];
                formatters = [ ];
                tasks = [
                  "all"
                  "check"
                  "generate-files"
                  "treefmt"
                  "write-files"
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
            testChecksAreCheckDependencies = {
              expr = {
                inherit
                  (summary (raw {
                    perSystem.process-compose.dev.settings.processes = {
                      custom.command = "true";
                      check.depends_on.custom.condition = "process_completed_successfully";
                    };
                  }))
                  tasks
                  checks
                  ;
              };
              expected = {
                tasks = [
                  "all"
                  "check"
                  "generate-files"
                  "treefmt"
                  "write-files"
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
                  "/.agents/skills/nk-resolve-file-conflicts"
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
                  "/.agents/skills/nk-resolve-file-conflicts"
                  "/.agents/skills/nk-upgrade"
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
            testTasksAllFormatsAndChecks = {
              expr = lib.attrNames (perSystem fixtures.md).processTrees.dev.processes.all.depends_on;
              expected = [
                "check"
                "flake-checker"
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
              expr = lib.mapAttrs (_: t: {
                flake = builtins.readFile (t.path + "/flake.nix");
                envrc = builtins.readFile (t.path + "/.envrc");
              }) nullkomma.templates;
              expected = lib.mapAttrs (_: t: {
                flake = builtins.readFile (root + "/tests/fixtures/md/flake.nix");
                envrc = (perSystem (callFlake t.path)).nullkomma.files.".envrc".text;
              }) nullkomma.templates;
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
                ${tasks} > menu
                grep -qF '[demo]' menu
                ${tasks} b 'local value'
                printf 'a\nb local value\n' | diff - log
                if ${tasks} broken; then exit 1; fi
                printf 'a\nb sandboxed value\n' | diff - ${sandboxed}
                ${tasks} graph | grep -qF 'b --> a'
                # MCP clients stop a stdio server with SIGTERM.
                mkfifo requests
                timeout 60 ${tasks} mcp < requests > mcp.out &
                server=$!
                exec 3> requests
                printf '%s\n' >&3 \
                  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' \
                  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
                  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
                  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"b","arguments":{"args":"mcp value"}}}'
                until grep -q '"id":3' mcp.out; do
                  kill -0 "$server"
                  sleep 0.2
                done
                kill "$server"
                grep -qF '"name":"b"' mcp.out
                grep -qF '"name":"pc_process_start"' mcp.out
                if grep -qF '"name":"serve"' mcp.out; then exit 1; fi
                tail -n 1 log | grep -qx 'b mcp value'
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
                ${at "old" "write-files"}
                ${at "old" "generate-files"}
                grep -q 'Generated by nullkomma. DO NOT EDIT' generated.txt
                # Unchanged generated files keep their mtime, so e.g. `quarto preview` doesn't re-render them.
                touch -d @0 generated.txt
                ${at "old" "generate-files"}
                test "$(stat -c %Y generated.txt)" = 0
                # Entering the dev shell regenerates only when the generated files changed.
                rm generated.txt
                (${(perSystem fileVersions.old).nullkomma.devShell.shellHook})
                test -f generated.txt
                rm generated.txt
                (${(perSystem fileVersions.old).nullkomma.devShell.shellHook})
                test ! -e generated.txt
                ${at "old" "generate-files"}
                printf 'project edit' > source.txt
                printf 'local edit' > generated.txt
                printf 'project edit' > edited.txt
                printf 'Project notes.\n\n%s\n' "$(cat notes.md)" > notes.md
                if ${at "new" "write-files"}; then
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
                ${at "new" "generate-files"} < /dev/null
                grep -q 'DO NOT EDIT' generated.txt
                test ! -e stale-generated.txt
                ${at "new" "write-files"} --accept source.txt
                ${at "new" "write-files"}
                test "$(cat source.txt)" = 'project edit'
                test "$(cat .git/nullkomma/files/base/source.txt)" = new
                test ! -f .git/nullkomma/files/incoming/source.txt
                mkdir ../unknown
                cd ../unknown
                git init --quiet
                printf 'preexisting' > source.txt
                if ${at "new" "write-files"}; then
                  echo "Unknown source-of-truth file was not reported" >&2
                  exit 1
                fi
                test "$(cat source.txt)" = preexisting
                test ! -f .git/nullkomma/files/base/source.txt
                ln -s source.txt generated.txt
                if ${at "new" "generate-files"}; then
                  echo "Symlink target was not rejected" >&2
                  exit 1
                fi
                test "$(cat source.txt)" = preexisting
                mkdir ../branded
                cd ../branded
                git init --quiet
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
