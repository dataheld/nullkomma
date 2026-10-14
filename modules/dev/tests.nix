# Contract tests: fixtures and templates are evaluated as consumers would,
# with their checks and devshells becoming checks of nullkomma itself.
{
  partitions.dev.module =
    { inputs, lib, ... }:
    let
      nullkomma = inputs.self;
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
        nullkomma.editor.vscode.enable = false;
        nullkomma.editor.vscode.extensions = [ "jnoortheen.nix-ide" ];
        nullkomma.editor.vscode.settings."nix.serverPath" = lib.mkForce "project-nixd";
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
          ".vscode/settings.json".mode = "shared";
          ".vscode/extensions.json".enable = false;
          "disabled-local" = {
            enable = false;
            mode = "generated";
            commentPrefix = "#";
            text = "";
          };
        };
      } ../../tests/fixtures/md;
      disabled = lib.genAttrs (lib.attrNames nullkomma.plugins) (
        name:
        callFlakeWith {
          nullkomma.${name}.enable = false;
        } ../../tests/fixtures/md
      );
      minimal = callFlakeWith {
        nullkomma =
          lib.genAttrs (lib.attrNames nullkomma.plugins) (_: {
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
              nullkomma.framework
              module
            ];
            debug = true;
          };
      rawFramework = raw { };
      rawUnselected = raw {
        imports = lib.attrValues nullkomma.plugins;
      };
      rawNix = raw {
        imports = [ nullkomma.plugins.nix ];
        nullkomma.nix.enable = true;
      };
      fileVersions = lib.genAttrs [ "old" "new" ] (
        version:
        raw {
          perSystem.nullkomma.files = {
            "shared.txt".text = version;
            "untouched.txt".text = version;
            "local.txt" = {
              text = version;
              mode = "generated";
              commentPrefix = "#";
            };
          };
        }
      );
      siteConsumer =
        name:
        raw {
          imports = [
            {
              perSystem =
                { pkgs, ... }:
                {
                  nullkomma.site = pkgs.writeTextDir "index.html" name;
                };
            }
          ];
          perSystem =
            { config, ... }:
            {
              nullkomma.tasks.read-site = {
                description = "Read a site through the neutral artifact contract";
                command = ''cat "${config.nullkomma.site}/index.html"'';
              };
            };
        };
      siteConsumers = lib.genAttrs [ "producer-a" "producer-b" ] siteConsumer;
      templates = lib.mapAttrs (_: t: callFlake t.path) nullkomma.templates;
    in
    {
      perSystem =
        { pkgs, system, ... }:
        let
          perSystem = flake: flake.allSystems.${system};
          has = attrs: name: attrs.${system} ? ${name};
          importTreeRoot = ../../tests/fixtures/import-tree;
          tests = {
            # keep-sorted start block=yes
            testAllPluginsDisabled = {
              expr = {
                files = lib.attrNames (perSystem minimal).nullkomma.files;
                tools = map (p: p.name) (perSystem minimal).nullkomma.devshell.packages;
                checks = lib.attrNames minimal.checks.${system};
                shells = lib.attrNames minimal.devShells.${system};
                extensions = minimal.editor.vscode.extensions;
                settings = minimal.editor.vscode.settings;
                tasks = lib.attrNames (perSystem minimal).nullkomma.tasks;
              };
              expected = {
                files = [ ];
                tools = [ ];
                checks = [ ];
                shells = [ ];
                extensions = [ ];
                settings = { };
                tasks = [
                  "generate-files"
                  "write-files"
                ];
              };
            };
            testConsumersExportSchemas = {
              expr = lib.mapAttrs (_: flake: {
                versions = map (name: flake.schemas.${name}.version) [
                  "apps"
                  "checks"
                  "devShells"
                  "formatter"
                  "packages"
                ];
                app =
                  (flake.schemas.apps.inventory flake.apps)
                  .children.${system}.children.write-files.evalChecks.isValidApp;
                check =
                  (flake.schemas.checks.inventory flake.checks).children.${system}.children.treefmt.isFlakeCheck;
                shell = (flake.schemas.devShells.inventory flake.devShells).children.${system}.children ? default;
                fh = lib.elem pkgs.fh (perSystem flake).nullkomma.devshell.packages;
                module = lib.all (plugin: plugin.evalChecks.isModule) (
                  lib.attrValues (flake.schemas.plugins.inventory nullkomma.plugins).children
                );
              }) (fixtures // lib.mapAttrs' (name: lib.nameValuePair "template-${name}") templates);
              expected =
                lib.genAttrs
                  [
                    "md"
                    "template-default"
                  ]
                  (_: {
                    versions = [
                      1
                      1
                      1
                      1
                      1
                    ];
                    app = true;
                    check = true;
                    shell = true;
                    fh = true;
                    module = true;
                  });
            };
            testConsumersCustomizeDefaults = {
              expr = {
                package = lib.elem pkgs.hello (perSystem customized).nullkomma.devshell.packages;
                disabled = (perSystem customized).treefmt.programs.deadnix.enable;
                enabled = (perSystem customized).treefmt.programs.typos.enable;
                formatter = customized.formatter.${system} == (perSystem customized).treefmt.build.wrapper;
              };
              expected = {
                package = true;
                disabled = false;
                enabled = true;
                formatter = true;
              };
            };
            testEditorDataWithoutWorkspaceFiles = {
              expr = {
                files = lib.filter (name: lib.hasPrefix ".vscode/" name) (
                  lib.attrNames (perSystem customized).nullkomma.files
                );
                extensions = customized.editor.vscode.extensions;
                settings = customized.editor.vscode.settings;
                personal = customized.editor.vscode.settings ? "nix.hiddenLanguageServerErrors";
                notebook = customized.editor.vscode.settings ? "notebook.defaultFormatter";
              };
              expected = {
                files = [ ];
                extensions = [
                  "arrterian.nix-env-selector"
                  "ibecker.treefmt-vscode"
                  "jnoortheen.nix-ide"
                ];
                settings = fixtures.md.editor.vscode.settings // {
                  "nix.serverPath" = "project-nixd";
                };
                personal = false;
                notebook = false;
              };
            };
            testGitignoreContainsOnlyPluginPatterns = {
              expr = (perSystem fixtures.md).nullkomma.files.".gitignore".text;
              expected = lib.concatLines [
                "result"
                "result-*"
                ".direnv/"
              ];
            };
            testGitignoreRespectsFileSelection = {
              expr = (perSystem fileSelection).nullkomma.files.".gitignore".text;
              expected = lib.concatLines [
                "result"
                "result-*"
                ".direnv/"
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
            testInitializedFilesAreUserOwned = {
              expr = {
                cron = (perSystem fixtures.md).nullkomma.files ? ".github/workflows/cron.yml";
                driftCheck = has fixtures.md.checks "files";
                banner =
                  lib.hasInfix "Generated by nullkomma"
                    (perSystem fixtures.md).nullkomma.files.".github/workflows/push.yml".text;
              };
              expected = {
                cron = false;
                driftCheck = false;
                banner = false;
              };
            };
            testPluginOptOuts = {
              expr = {
                github =
                  !(perSystem disabled.github).nullkomma.files ? ".github/workflows/push.yml"
                  && !(perSystem disabled.github).treefmt.programs.actionlint.enable;
                markdown = !(perSystem disabled.markdown).treefmt.programs.mdformat.enable;
                json = !(perSystem disabled.json).treefmt.programs.jsonfmt.enable;
                yaml = !(perSystem disabled.yaml).treefmt.programs.yamlfmt.enable;
                toml = !(perSystem disabled.toml).treefmt.programs.toml-sort.enable;
                shell =
                  !(perSystem disabled.shell).treefmt.programs.shfmt.enable
                  && !(perSystem disabled.shell).treefmt.programs.shellcheck.enable;
                keepSorted = !(perSystem disabled.keepSorted).treefmt.programs.keep-sorted.enable;
                nix =
                  !(perSystem disabled.nix).treefmt.programs.nixfmt.enable
                  && !(perSystem disabled.nix).treefmt.programs.deadnix.enable
                  && !(lib.elem pkgs.nixd (perSystem disabled.nix).nullkomma.devshell.packages)
                  && !(disabled.nix.editor.vscode.settings ? "nix.serverPath")
                  && !((perSystem disabled.nix).nullkomma.tasks ? "check");
                git =
                  !((perSystem disabled.git).nullkomma.files ? ".gitignore")
                  && !(lib.elem pkgs.git (perSystem disabled.git).nullkomma.devshell.packages);
                direnv =
                  !((perSystem disabled.direnv).nullkomma.files ? ".envrc")
                  && !(lib.elem ".direnv/" disabled.direnv.debug.config.nullkomma.gitignore)
                  && !(lib.elem "arrterian.nix-env-selector" disabled.direnv.editor.vscode.extensions);
                editor =
                  disabled.editor.editor.vscode.extensions == [ ]
                  && disabled.editor.editor.vscode.settings == { }
                  && lib.all (name: !(lib.hasPrefix ".vscode/" name)) (
                    lib.attrNames (perSystem disabled.editor).nullkomma.files
                  );
                treefmt =
                  !((disabled.treefmt.checks.${system}) ? treefmt)
                  && !(lib.elem (perSystem disabled.treefmt).treefmt.build.wrapper (perSystem disabled.treefmt)
                  .nullkomma.devshell.packages)
                  && !(disabled.treefmt.editor.vscode.settings ? "nix.formatterPath");
                flakehub = !(lib.elem pkgs.fh (perSystem disabled.flakehub).nullkomma.devshell.packages);
              };
              expected = lib.genAttrs (lib.attrNames nullkomma.plugins) (_: true);
            };
            testRawPluginAssembly = {
              expr = {
                checks = lib.attrNames rawFramework.checks.${system};
                unselected = {
                  checks = lib.attrNames rawUnselected.checks.${system};
                  tools = map (p: p.name) (perSystem rawUnselected).nullkomma.devshell.packages;
                  files = lib.attrNames (perSystem rawUnselected).nullkomma.files;
                };
                tools = (perSystem rawFramework).nullkomma.devshell.packages;
                files = lib.attrNames (perSystem rawFramework).nullkomma.files;
                nix = (perSystem rawNix).treefmt.programs.nixfmt.enable;
                tasks = lib.attrNames (perSystem rawNix).nullkomma.tasks;
                editor = rawNix.editor.vscode.settings;
              };
              expected = {
                checks = [ ];
                unselected = {
                  checks = [ ];
                  tools = [ ];
                  files = [ ];
                };
                tools = [ ];
                files = [ ];
                nix = true;
                tasks = [
                  "check"
                  "flake-checker"
                  "generate-files"
                  "update"
                  "write-files"
                ];
                editor = { };
              };
            };
            testPluginExports = {
              expr = {
                names = lib.attrNames nullkomma.plugins;
                class = nullkomma.plugins.nix._class;
                schema = nullkomma.schemas.plugins.version;
                framework = (nullkomma.schemas.framework.inventory nullkomma.framework).evalChecks.isModule;
                legacy = lib.filter (name: builtins.hasAttr name nullkomma) [
                  "flakeModule"
                  "flakeModules"
                  "modules"
                ];
              };
              expected = {
                names = nullkomma.lib.defaultPlugins;
                class = "flake";
                schema = 1;
                framework = true;
                legacy = [ ];
              };
            };
            testSiteIsOptional = {
              expr = {
                site = (perSystem rawFramework).nullkomma.site;
                package = rawFramework.packages.${system} ? site;
              };
              expected = {
                site = null;
                package = false;
              };
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
          failures = lib.debug.runTests tests;
          fixtureChecks = lib.concatMapAttrs (
            name: flake:
            lib.mapAttrs' (check: lib.nameValuePair "fixture-${name}-${check}") (
              flake.checks.${system}
              // {
                devshell = flake.devShells.${system}.default;
              }
            )
          ) fixtures;
        in
        {
          nullkomma.tasks.check-fixtures = {
            description = "Check a real consumer flake accepts valid input and rejects formatting drift";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              pkgs.gnugrep
            ];
            command = ''
              root="$(git rev-parse --show-toplevel)"
              scratch="$(mktemp -d)"
              trap 'rm -f "$scratch/project/flake.nix" "$scratch/project/README.md" "$scratch/project/unformatted.nix" "$scratch/failure.log"; rmdir "$scratch/project" "$scratch"' EXIT
              mkdir "$scratch/project"
              cp "$root/tests/fixtures/md/flake.nix" "$root/tests/fixtures/md/README.md" "$scratch/project/"
              nix flake check "path:$scratch/project" \
                --override-input nullkomma "path:$root" \
                --no-write-lock-file --print-build-logs

              printf '{foo=1;}\n' > "$scratch/project/unformatted.nix"
              if nix flake check "path:$scratch/project" \
                --override-input nullkomma "path:$root" \
                --no-write-lock-file --print-build-logs > "$scratch/failure.log" 2>&1; then
                echo "Invalid consumer unexpectedly passed nix flake check" >&2
                exit 1
              fi
              cat "$scratch/failure.log"
              grep -qF 'diff --git a/unformatted.nix b/unformatted.nix' "$scratch/failure.log"
              grep -qF '+{ foo = 1; }' "$scratch/failure.log"
            '';
          };
          checks = fixtureChecks // {
            site-contract = pkgs.runCommandLocal "nullkomma-site-contract" { } (
              lib.concatMapStringsSep "\n" (
                name:
                let
                  flake = siteConsumers.${name};
                in
                ''
                  ${flake.apps.${system}.read-site.program} > actual
                  printf '%s' '${name}' > expected
                  cmp actual expected
                  cmp actual ${flake.packages.${system}.site}/index.html
                ''
              ) (lib.attrNames siteConsumers)
              + "\ntouch $out\n"
            );
            formatting-rejects = pkgs.testers.testBuildFailure' {
              name = "nullkomma-formatting-rejects";
              drv = (perSystem fixtures.md).treefmt.build.check (pkgs.writeTextDir "flake.nix" "{foo=1;}\n");
              expectedBuilderExitCode = 1;
              expectedBuilderLogEntries = [
                "diff --git a/flake.nix b/flake.nix"
                "+{ foo = 1; }"
              ];
            };
            file-initialization =
              pkgs.runCommandLocal "nullkomma-file-initialization"
                {
                  nativeBuildInputs = [ pkgs.git ];
                }
                ''
                  mkdir project
                  cd project
                  git init --quiet
                  ${fixtures.md.apps.${system}.write-files.program}
                  ${fixtures.md.apps.${system}.generate-files.program}
                  git -c core.excludesFile=/dev/null check-ignore --no-index .vscode/settings.json .vscode/extensions.json
                  for path in .gitignore .github/workflows/push.yml; do
                    if git -c core.excludesFile=/dev/null check-ignore --no-index "$path"; then
                      echo "Shared file unexpectedly ignored: $path" >&2
                      exit 1
                    fi
                  done
                  test -f .github/workflows/push.yml
                  test ! -e .github/workflows/cron.yml
                  test -w .github/workflows/push.yml
                  if grep -q 'Generated by nullkomma' .github/workflows/push.yml; then
                    exit 1
                  fi
                  printf '# My workflow\n' > .github/workflows/push.yml
                  ${fixtures.md.apps.${system}.write-files.program}
                  printf '# My workflow\n' > expected
                  cmp expected .github/workflows/push.yml
                  test ! -e .github/workflows/cron.yml
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
                  ${fileVersions.old.apps.${system}.write-files.program}
                  ${fileVersions.old.apps.${system}.generate-files.program}
                  grep -q 'Generated by nullkomma. DO NOT EDIT' local.txt
                  test "$(stat -c %a local.txt)" = 444
                  git -c core.excludesFile=/dev/null check-ignore local.txt
                  printf 'project edit' > shared.txt
                  chmod u+w local.txt
                  printf 'local edit' > local.txt
                  if ${fileVersions.new.apps.${system}.write-files.program} > conflict.log 2>&1; then
                    echo "Edited shared file unexpectedly overwritten" >&2
                    exit 1
                  fi
                  grep -q 'resolve-file-conflicts' conflict.log
                  test "$(cat shared.txt)" = 'project edit'
                  test "$(cat untouched.txt)" = new
                  test "$(cat .git/nullkomma/files/base/shared.txt)" = old
                  test "$(cat .git/nullkomma/files/incoming/shared.txt)" = new
                  if ${fileVersions.new.apps.${system}.generate-files.program} < /dev/null; then
                    echo "Generated file overwritten without consent" >&2
                    exit 1
                  fi
                  test "$(cat local.txt)" = 'local edit'
                  ${fileVersions.new.apps.${system}.generate-files.program} --yes
                  grep -q 'DO NOT EDIT' local.txt
                  test "$(tail -n 1 local.txt)" = new
                  ${fileVersions.new.apps.${system}.write-files.program} --accept-shared shared.txt
                  ${fileVersions.new.apps.${system}.write-files.program}
                  test "$(cat shared.txt)" = 'project edit'
                  test "$(cat .git/nullkomma/files/base/shared.txt)" = new
                  test ! -f .git/nullkomma/files/incoming/shared.txt
                  git add -f local.txt
                  if ${fileVersions.new.apps.${system}.generate-files.program} --yes; then
                    echo "Tracked generated file was not rejected" >&2
                    exit 1
                  fi
                  mkdir ../unknown
                  cd ../unknown
                  git init --quiet
                  printf 'preexisting' > shared.txt
                  if ${fileVersions.new.apps.${system}.write-files.program}; then
                    echo "Unknown shared file was not reported" >&2
                    exit 1
                  fi
                  test "$(cat shared.txt)" = preexisting
                  test ! -f .git/nullkomma/files/base/shared.txt
                  ln -s shared.txt local.txt
                  if ${fileVersions.new.apps.${system}.generate-files.program} --yes; then
                    echo "Symlink target was not rejected" >&2
                    exit 1
                  fi
                  test "$(cat shared.txt)" = preexisting
                  touch $out
                '';
            file-update-task =
              let
                nix = pkgs.writeShellScriptBin "nix" ''
                  printf '%s\n' "$*" >> "$NULLKOMMA_TEST_LOG"
                  case "$*" in
                    "flake update fail") exit 7 ;;
                    "run .#write-files") exit 1 ;;
                  esac
                '';
              in
              pkgs.runCommandLocal "nullkomma-file-update-task"
                {
                  nativeBuildInputs = [ nix ];
                }
                ''
                  export NULLKOMMA_TEST_LOG="$PWD/calls"
                  if ${fixtures.md.apps.${system}.update.program} nullkomma; then
                    echo "Update did not propagate file conflicts" >&2
                    exit 1
                  fi
                  printf '%s\n' 'flake update nullkomma' 'run .#write-files' 'run .#generate-files' > expected
                  cmp calls expected
                  : > calls
                  if ${fixtures.md.apps.${system}.update.program} fail; then
                    echo "Failed lock update was not propagated" >&2
                    exit 1
                  fi
                  printf '%s\n' 'flake update fail' > expected
                  cmp calls expected
                  touch $out
                '';
            unit = pkgs.runCommandLocal "nullkomma-unit-tests" { } (
              if failures == [ ] then
                "touch $out"
              else
                ''
                  cat >&2 <<'EOF'
                  ${lib.generators.toPretty { } failures}
                  EOF
                  exit 1
                ''
            );
          };
        };
    };
}
