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
                module =
                  (flake.schemas.flakeModules.inventory {
                    default = nullkomma.flakeModules.default;
                  }).children.default.evalChecks.isModule;
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
            testTemplatesAreFixtures = {
              expr = builtins.readFile ../../templates/default/flake.nix;
              expected = builtins.readFile ../../tests/fixtures/md/flake.nix;
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
          checks = fixtureChecks // {
            formatting-rejects =
              pkgs.runCommandLocal "nullkomma-formatting-rejects"
                {
                  failure = pkgs.testers.testBuildFailure (
                    (perSystem fixtures.md).treefmt.build.check (pkgs.writeTextDir "flake.nix" "{foo=1;}\n")
                  );
                }
                ''
                  grep -qF 'diff --git a/flake.nix b/flake.nix' "$failure/testBuildFailure.log"
                  grep -qF '+{ foo = 1; }' "$failure/testBuildFailure.log"
                  touch $out
                '';
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
