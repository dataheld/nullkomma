# Contract tests: fixtures and templates are evaluated as consumers would,
# with their checks and devshells becoming checks of nullkomma itself.
{
  partitions.dev.module =
    { inputs, lib, ... }:
    let
      nullkomma = inputs.self;
      plugins = removeAttrs nullkomma.flakeModules [
        "default"
        "framework"
      ];
      callFlakeWith =
        module: src:
        let
          flake = import (src + "/flake.nix");
          debugged = nullkomma // {
            lib = nullkomma.lib // {
              mkFlake =
                args: consumer:
                nullkomma.lib.mkFlake args {
                  imports = [
                    consumer
                    module
                  ];
                  debug = true;
                };
            };
          };
          flakeInputs = {
            self = self';
            nullkomma = debugged;
          };
          outputs = flake.outputs flakeInputs;
          self' = outputs // {
            _type = "flake";
            outPath = src;
            sourceInfo.outPath = src;
            inputs = flakeInputs;
            inherit outputs;
          };
        in
        self';
      callFlake = callFlakeWith { };
      fixtures = {
        md = callFlake ../../tests/fixtures/md;
      };
      customized = callFlakeWith {
        nullkomma.editor.vscode.settings."nix.serverPath" = "project-nixd";
        perSystem =
          { pkgs, ... }:
          {
            nullkomma.devshell.packages = [ pkgs.hello ];
            treefmt.programs.deadnix.enable = false;
            treefmt.programs.typos.enable = true;
          };
      } ../../tests/fixtures/md;
      fileSelection = callFlakeWith {
        perSystem.nullkomma.files = {
          ".vscode/settings.json".mode = "source";
          ".vscode/extensions.json".enable = false;
          "disabled-local" = {
            enable = false;
            mode = "generated";
            commentPrefix = "#";
            text = "";
          };
        };
      } ../../tests/fixtures/md;
      disabled = lib.genAttrs (lib.attrNames plugins) (
        name:
        callFlakeWith {
          nullkomma.${name}.enable = false;
        } ../../tests/fixtures/md
      );
      minimal = callFlakeWith {
        nullkomma =
          lib.genAttrs (lib.attrNames plugins) (_: {
            enable = false;
          })
          // {
            devshell.enable = false;
          };
      } ../../tests/fixtures/md;
      raw =
        module:
        inputs.flake-parts.lib.mkFlake
          {
            inputs.self.outPath = ../../tests/fixtures/md;
          }
          {
            imports = [
              nullkomma.flakeModules.framework
              module
            ];
            debug = true;
          };
      rawFramework = raw { };
      rawUnselected = raw {
        imports = lib.attrValues plugins;
      };
      rawNix = raw {
        imports = [ plugins.nix ];
        nullkomma.nix.enable = true;
      };
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
          };
        }
      );
      templates = lib.mapAttrs (_: t: callFlake t.path) nullkomma.templates;
      # Every way to import nullkomma at once; keys make the module system import each once.
      overlapping = callFlakeWith {
        imports = [
          nullkomma.flakeModules.framework
          nullkomma.flakeModules.nix
          nullkomma.modules.flake.nix
          nullkomma.modules.flake.default
        ];
      } ../../tests/fixtures/md;
    in
    {
      imports = [ inputs.nix-unit.modules.flake.default ];
      flake.schemas.tests = {
        version = 1;
        doc = "[nix-unit](https://github.com/nix-community/nix-unit) tests, run by `checks.<system>.nix-unit`.";
        inventory = output: {
          children = builtins.mapAttrs (_: _: { what = "nix-unit test suite"; }) output;
        };
      };
      perSystem =
        { pkgs, system, ... }:
        let
          perSystem = flake: flake.allSystems.${system};
          importTreeRoot = ../../tests/fixtures/import-tree;
          # What plugins can contribute to a consumer flake.
          summary = flake: {
            files = lib.attrNames (perSystem flake).nullkomma.files;
            tools = map lib.getName (perSystem flake).nullkomma.devshell.packages;
            formatters = lib.attrNames (perSystem flake).treefmt.build.programs;
            tasks = lib.attrNames (perSystem flake).nullkomma.tasks;
            checks = lib.attrNames flake.checks.${system};
            shells = lib.attrNames flake.devShells.${system};
            inherit (flake.debug.config.nullkomma) editor;
          };
          tests = {
            # keep-sorted start block=yes
            testAllPluginsDisabledIsBareFramework = {
              expr = map summary [
                rawFramework
                rawUnselected
                minimal
              ];
              expected = lib.replicate 3 {
                files = [ ];
                tools = [
                  "generate-files"
                  "write-files"
                  "tasks"
                ];
                formatters = [ ];
                tasks = [
                  "generate-files"
                  "write-files"
                ];
                checks = [ ];
                shells = [ ];
                editor = {
                  formatCommand = null;
                  languageServers = { };
                  vscode = {
                    extensions = [ ];
                    settings = { };
                  };
                };
              };
            };
            testConsumersCustomizeDefaults = {
              expr = {
                package = lib.elem pkgs.hello (perSystem customized).nullkomma.devshell.packages;
                disabled = (perSystem customized).treefmt.programs.deadnix.enable;
                enabled = (perSystem customized).treefmt.programs.typos.enable;
                setting = customized.debug.config.nullkomma.editor.vscode.settings."nix.serverPath";
              };
              expected = {
                package = true;
                disabled = false;
                enabled = true;
                setting = "project-nixd";
              };
            };
            testEveryPluginCanBeDisabled = {
              expr = lib.filter (name: summary disabled.${name} == summary fixtures.md) (lib.attrNames plugins);
              expected = [ ];
            };
            testGitignoreContainsPluginPatternsAndGeneratedFiles = {
              expr = (perSystem fixtures.md).nullkomma.files.".gitignore".text;
              expected = lib.concatLines [
                "result"
                "result-*"
                ".direnv/"
                "/.nvim.lua"
                "/.vscode/extensions.json"
                "/.vscode/settings.json"
              ];
            };
            testGitignoreRespectsFileSelection = {
              expr = (perSystem fileSelection).nullkomma.files.".gitignore".text;
              expected = lib.concatLines [
                "result"
                "result-*"
                ".direnv/"
                "/.nvim.lua"
              ];
            };
            testImportTreeSkipsUnderscoresAndNonNix = {
              expr = map (lib.removePrefix (toString importTreeRoot)) (
                map toString (nullkomma.lib.importTree importTreeRoot)
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
                expr = normalize (summary overlapping);
                expected = normalize (summary fixtures.md);
              };
            testPluginWorksWithoutOthers = {
              expr = {
                inherit (summary rawNix) formatters;
                inherit (rawNix.debug.config.nullkomma.editor.languageServers.nixd) settings;
              };
              expected = {
                formatters = [
                  "deadnix"
                  "nixf-diagnose"
                  "nixfmt"
                ];
                settings = { };
              };
            };
            testTasksAllSkipsMutatingTasks = {
              expr = lib.attrNames (
                lib.filterAttrs (_: t: !(t.skip or false)) (perSystem fixtures.md).nullkomma.tasks
              );
              expected = [
                "check"
                "flake-checker"
              ];
            };
            testTemplatesAreFixtures = {
              expr = builtins.readFile ../../templates/default/flake.nix;
              expected = builtins.readFile ../../tests/fixtures/md/flake.nix;
            };
            testTemplatesIncludeDirenvBootstrap = {
              expr = builtins.readFile (nullkomma.templates.default.path + "/.envrc");
              expected = (perSystem templates.default).nullkomma.files.".envrc".text;
            };
            # keep-sorted end
          };
          fixtureChecks = lib.concatMapAttrs (
            name: flake:
            lib.mapAttrs' (check: lib.nameValuePair "fixture-${name}-${check}") (
              flake.checks.${system}
              // {
                devshell = flake.devShells.${system}.default;
              }
            )
          ) fixtures;
          # One invalid file per formatter, checked by both the derivation and the real CLI.
          rejects = {
            nix = {
              file = "unformatted.nix";
              content = "{foo=1;}\n";
              expect = [
                "diff --git a/unformatted.nix b/unformatted.nix"
                "+{ foo = 1; }"
              ];
            };
            markdown = {
              file = "unformatted.md";
              content = "# Title\n* item\n";
              expect = [
                "diff --git a/unformatted.md b/unformatted.md"
                "+- item"
              ];
            };
          };
        in
        {
          # Sandboxed: nix-unit re-evaluates this flake, fetching dev inputs (../../dev).
          nix-unit = {
            package = pkgs.nix-unit;
            inputs = {
              inherit (inputs)
                flake-parts
                flake-schemas
                nixpkgs
                treefmt-nix
                up
                ;
            };
            allowNetwork = true;
            inherit tests;
          };
          nullkomma.tasks.check-fixtures = {
            description = "Check a real consumer flake accepts valid input and rejects formatting drift";
            packages = [
              pkgs.coreutils
              pkgs.git
              pkgs.gnugrep
            ];
            command = ''
              root="$(git rev-parse --show-toplevel)"
              scratch="$(mktemp -d)"
              trap 'rm -rf "$scratch"' EXIT
              mkdir "$scratch/project"
              cp "$root/tests/fixtures/md/flake.nix" "$root/tests/fixtures/md/README.md" "$scratch/project/"
              check() {
                nix flake check "path:$scratch/project" \
                  --override-input nullkomma "path:$root" \
                  --no-write-lock-file --print-build-logs
              }
              check
            ''
            + lib.concatMapStrings (case: ''

              printf %s ${lib.escapeShellArg case.content} > "$scratch/project/${case.file}"
              if check > "$scratch/failure.log" 2>&1; then
                echo "Consumer with invalid ${case.file} unexpectedly passed nix flake check" >&2
                exit 1
              fi
              cat "$scratch/failure.log"
              ${lib.concatMapStrings (entry: ''
                grep -qF -- ${lib.escapeShellArg entry} "$scratch/failure.log"
              '') case.expect}
              rm "$scratch/project/${case.file}"
            '') (lib.attrValues rejects);
          };
          checks =
            fixtureChecks
            // lib.mapAttrs' (
              name: case:
              lib.nameValuePair "formatting-rejects-${name}" (
                pkgs.testers.testBuildFailure' {
                  name = "nullkomma-formatting-rejects-${name}";
                  drv = (perSystem fixtures.md).treefmt.build.check (
                    pkgs.runCommandLocal "unformatted-${name}" { } ''
                      mkdir $out
                      printf '{ }\n' > $out/flake.nix
                      printf %s ${lib.escapeShellArg case.content} > $out/${case.file}
                    ''
                  );
                  expectedBuilderExitCode = 1;
                  expectedBuilderLogEntries = case.expect;
                }
              )
            ) rejects
            // {
              neovim-config =
                pkgs.runCommandLocal "nullkomma-neovim-config" { nativeBuildInputs = [ pkgs.neovim-unwrapped ]; }
                  ''
                    HOME=$TMPDIR nvim --clean -l ${pkgs.writeText "check.lua" ''
                      dofile("${(perSystem fixtures.md).nullkomma.files.".nvim.lua".source}")
                      assert(vim.lsp.config.nixd.cmd[1] == "nixd")
                      assert(vim.lsp.config.nixd.settings.nixd.formatting.command[1] == "treefmt")
                      assert(vim.lsp.is_enabled("nixd"))
                    ''}
                    touch $out
                  '';
              # Every language server an editor is told to start is in the dev shell.
              language-servers =
                pkgs.runCommandLocal "nullkomma-language-servers"
                  { nativeBuildInputs = (perSystem fixtures.md).nullkomma.devshell.packages; }
                  ''
                    ${lib.concatMapStrings (s: ''
                      command -v ${lib.escapeShellArg (lib.head s.command)}
                    '') (lib.attrValues fixtures.md.debug.config.nullkomma.editor.languageServers)}
                    touch $out
                  '';
              file-updates =
                pkgs.runCommandLocal "nullkomma-file-updates"
                  {
                    nativeBuildInputs = [ pkgs.git ];
                  }
                  ''
                    mkdir project
                    cd project
                    git init --quiet
                    ${lib.getExe (perSystem fileVersions.old).nullkomma.tasks.write-files.package}
                    ${lib.getExe (perSystem fileVersions.old).nullkomma.tasks.generate-files.package}
                    grep -q 'Generated by nullkomma. DO NOT EDIT' generated.txt
                    printf 'project edit' > source.txt
                    printf 'local edit' > generated.txt
                    if ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package}; then
                      echo "Edited source-of-truth file unexpectedly overwritten" >&2
                      exit 1
                    fi
                    test "$(cat source.txt)" = 'project edit'
                    test "$(cat untouched.txt)" = new
                    test "$(cat .git/nullkomma/files/base/source.txt)" = old
                    test "$(cat .git/nullkomma/files/incoming/source.txt)" = new
                    ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.generate-files.package} < /dev/null
                    grep -q 'DO NOT EDIT' generated.txt
                    test "$(tail -n 1 generated.txt)" = new
                    ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package} --accept source.txt
                    ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package}
                    test "$(cat source.txt)" = 'project edit'
                    test "$(cat .git/nullkomma/files/base/source.txt)" = new
                    test ! -f .git/nullkomma/files/incoming/source.txt
                    mkdir ../unknown
                    cd ../unknown
                    git init --quiet
                    printf 'preexisting' > source.txt
                    if ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.write-files.package}; then
                      echo "Unknown source-of-truth file was not reported" >&2
                      exit 1
                    fi
                    test "$(cat source.txt)" = preexisting
                    test ! -f .git/nullkomma/files/base/source.txt
                    ln -s source.txt generated.txt
                    if ${lib.getExe (perSystem fileVersions.new).nullkomma.tasks.generate-files.package}; then
                      echo "Symlink target was not rejected" >&2
                      exit 1
                    fi
                    test "$(cat source.txt)" = preexisting
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
                in
                pkgs.runCommandLocal "nullkomma-file-update-task"
                  {
                    nativeBuildInputs = [ nix ];
                  }
                  ''
                    export NULLKOMMA_TEST_LOG="$PWD/calls"
                    if ${lib.getExe (perSystem fixtures.md).nullkomma.tasks.update.package} nullkomma; then
                      echo "Update did not propagate file conflicts" >&2
                      exit 1
                    fi
                    printf '%s\n' 'flake update nullkomma' 'develop --command write-files' 'develop --command generate-files' > expected
                    cmp calls expected
                    : > calls
                    if ${lib.getExe (perSystem fixtures.md).nullkomma.tasks.update.package} fail; then
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
                      visible = opt.visible && lib.any (lib.hasPrefix (toString ../..)) opt.declarations;
                    };
                  warningsAreErrors = true;
                }).optionsCommonMark;
            };
        };
    };
}
