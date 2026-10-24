{
  partitions.dev.module =
    { inputs, ... }:
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
              command = "echo a >> log";
              watch.paths = [ "flake.nix" ];
            };
            b = {
              after = [ "a" ];
              command = "echo b >> log";
            };
            c = {
              after = [
                "a"
                "b"
              ];
              command = ''echo c "$@" >> log'';
              watch.paths = [ "missing" ];
            };
            broken.command = "exit 3";
            d = {
              after = [ "broken" ];
              command = "echo d >> log";
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
                  "format"
                  "generate-files"
                  "write-files"
                  "tasks"
                  "treefmt"
                ];
                formatters = [ ];
                tasks = [
                  "format"
                  "generate-files"
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
                  "check"
                  "format"
                  "generate-files"
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
            testEveryPluginCanBeDisabled = {
              expr = lib.filter (
                name:
                summary (
                  callFlakeWith
                    {
                      imports = [ { nullkomma.cloudflare.worker = "fixture-site"; } ];
                      nullkomma.${name}.enable = !fixtures.md.debug.config.nullkomma.${name}.enable;
                    }
                    (
                      if
                        lib.elem name [
                          "r"
                          "r-non-nix"
                        ]
                      then
                        root + "/tests/fixtures/r"
                      else
                        md
                    )
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
                  "/.nvim.lua"
                  "/.vscode/extensions.json"
                  "/.vscode/settings.json"
                ])
                (lib.concatLines [
                  "result"
                  "result-*"
                  ".direnv/"
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
                  tasks = lib.filter (lib.hasPrefix "dev-") (lib.attrNames flake.nullkomma.tasks);
                  processes = lib.attrNames flake.processTrees.tree.processes;
                  watches = lib.filter (lib.hasPrefix "watch-") (map lib.getName flake.nullkomma.devShell.packages);
                };
                expected = {
                  closure = [
                    "a"
                    "b"
                    "c"
                  ];
                  tasks = [ "dev-tree" ];
                  processes = [
                    "a"
                    "b"
                    "c"
                  ];
                  # c's own path is missing, but it watches a's inputs too.
                  watches = [
                    "watch-a"
                    "watch-c"
                  ];
                };
              };
            testTasksAllHonorsSkip = {
              expr = lib.attrNames (
                lib.filterAttrs (_: t: !(t.skip or false)) (perSystem fixtures.md).nullkomma.tasks
              );
              expected = [
                "check"
                "flake-checker"
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
            # keep-sorted end
          };
          checks = {
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
                touch $out
              '';
            task-menu =
              let
                flake = raw {
                  perSystem.nullkomma.checks.custom.command = "echo custom-check";
                };
                runner = (perSystem flake).taskRunners.default;
              in
              pkgs.runCommand "nullkomma-task-menu" { } ''
                ${lib.getExe pkgs.git} init -q
                ${lib.getExe runner} > menu
                grep -qF 'check <name> [args]: custom' menu
                grep -qF "for arguments, run the listed command directly" menu
                ${lib.getExe runner} check > checked
                grep -qF custom-check checked
                ${lib.getExe runner} all > checked-all
                grep -qF custom-check checked-all
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
                generate=${task fixtures.quarto-branded "generate-files"}
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
                    "develop --command write-files") exit 1 ;;
                  esac
                '';
                update = task fixtures.md "update";
              in
              pkgs.runCommandLocal "nullkomma-file-update-task" { nativeBuildInputs = [ nix ]; } ''
                export NULLKOMMA_TEST_LOG="$PWD/calls"
                if ${update} nullkomma; then
                  echo "Update did not propagate file conflicts" >&2
                  exit 1
                fi
                printf '%s\n' 'flake update nullkomma' 'develop --command write-files' 'develop --command generate-files' > expected
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
            agent-plugin-consumer =
              pkgs.runCommandLocal "nullkomma-agent-plugin-consumer" { nativeBuildInputs = [ pkgs.coreutils ]; }
                ''
                  plugin="$TMPDIR/home/.copilot/installed-plugins/_direct/nullkomma"
                  mkdir -p "$plugin/.github"
                  cp ${root + "/plugin.json"} "$plugin/plugin.json"
                  cp -R ${root + "/.github/skills"} "$plugin/.github/skills"
                  cp -P ${root + "/skills"} "$plugin/skills"
                  grep -qF 'name: resolve-file-conflicts' "$plugin/skills/resolve-file-conflicts/SKILL.md"
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
