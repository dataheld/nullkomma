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
                tasks = [ "write-files" ];
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
            testGitignoreReincludesManagedFiles = {
              expr =
                let
                  lines = lib.splitString "\n" (perSystem fixtures.md).nullkomma.files.".gitignore".text;
                in
                {
                  envrc = lib.elem "!/.envrc" lines;
                  vscode = lib.elem "!/.vscode/settings.json" lines;
                  last = lib.last (lib.init lines) == "!/.vscode/settings.json";
                };
              expected = {
                envrc = true;
                vscode = true;
                last = true;
              };
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
            file-initialization = pkgs.runCommandLocal "nullkomma-file-initialization" { } ''
              mkdir project
              cd project
              ${fixtures.md.apps.${system}.write-files.program}
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
