# Contract tests: unit tests of ./lib, plus fixtures and templates evaluated as
# consumers would (nullkomma as their only input), whose checks, devshells and
# sites become checks of nullkomma itself.
{
  partitions.dev.module =
    { inputs, lib, ... }:
    let
      nullkomma = inputs.self;
      # Like `builtins.getFlake`, but pure and with `nullkomma` pointing at this
      # checkout; flake-parts' `debug` exposes the configuration to the tests.
      callFlake =
        src:
        let
          flake = import (src + "/flake.nix");
          debugged = nullkomma // {
            lib = nullkomma.lib // {
              mkFlake =
                args: module:
                nullkomma.lib.mkFlake args {
                  imports = [ module ];
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
      fixtures = lib.genAttrs [ "md" "r" "quarto" ] (name: callFlake ../../tests/fixtures/${name});
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
            testGitignoreReincludesManagedFiles = {
              expr =
                let
                  lines = lib.splitString "\n" (perSystem fixtures.r).nullkomma.files.".gitignore".text;
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
            testMdHasNoR = {
              expr = {
                air = (perSystem fixtures.md).treefmt.programs.air.enable;
                options = fixtures.md.debug.options.nullkomma ? r;
                check = has fixtures.md.checks "r-cmd-check";
              };
              expected = {
                air = false;
                options = false;
                check = false;
              };
            };
            testQuartoComposesWithR = {
              expr = {
                engines = map (p: p.name) (perSystem fixtures.quarto).nullkomma.quarto.engines;
                knitr = lib.elem "knitr" fixtures.quarto.debug.nullkomma.r.extraPackages;
                env = (perSystem fixtures.quarto).nullkomma.devshell.env ? QUARTO_R;
                check = has fixtures.quarto.checks "r-cmd-check";
              };
              expected = {
                engines = [ (perSystem fixtures.quarto).nullkomma.r.package.name ];
                knitr = true;
                env = true;
                check = false;
              };
            };
            testQuartoDeploys = {
              expr = {
                site = has fixtures.quarto.packages "site";
                deploy = has fixtures.quarto.apps "deploy";
                ci =
                  lib.hasInfix "CLOUDFLARE_API_TOKEN: \${{ secrets.CLOUDFLARE_API_TOKEN }}"
                    (perSystem fixtures.quarto).nullkomma.files.".github/workflows/push.yml".text;
              };
              expected = {
                site = true;
                deploy = true;
                ci = true;
              };
            };
            testQuartoTemplateWithoutProjectHasNoSite = {
              expr = {
                site = has templates.quarto.packages "site";
                tasks = lib.attrNames (
                  lib.filterAttrs (
                    n: _:
                    lib.elem n [
                      "preview"
                      "render"
                    ]
                  ) templates.quarto.apps.${system}
                );
              };
              expected = {
                site = false;
                tasks = [
                  "preview"
                  "render"
                ];
              };
            };
            testRDependsOnDescription = {
              expr = nullkomma.lib.r.depsFromDescription { path = ../../tests/fixtures/r/DESCRIPTION; };
              expected = [ "testthat" ];
            };
            testRHasAirAndCheck = {
              expr = {
                air = (perSystem fixtures.r).treefmt.programs.air.enable;
                check = has fixtures.r.checks "r-cmd-check";
                gitignore = lib.elem "*.Rcheck/" fixtures.r.debug.nullkomma.gitignore;
              };
              expected = {
                air = true;
                check = true;
                gitignore = true;
              };
            };
            testRLibAttrName = {
              expr = nullkomma.lib.r.attrName "data.table";
              expected = "data_table";
            };
            testRLibDepNames = {
              expr = nullkomma.lib.r.depNames "R (>= 4.1), data.table (>= 1.0),\n  rlang, utils";
              expected = [
                "data.table"
                "rlang"
              ];
            };
            testRLibParseDCF = {
              expr = nullkomma.lib.r.parseDCF ''
                Package: foo
                Imports:
                    bar,
                    baz (>= 1.0)
              '';
              expected = {
                Package = "foo";
                Imports = "bar, baz (>= 1.0)";
              };
            };
            testTemplatesAreFixtures = {
              expr = map builtins.readFile [
                ../../templates/default/flake.nix
                ../../templates/r/flake.nix
              ];
              expected = map builtins.readFile [
                ../../tests/fixtures/md/flake.nix
                ../../tests/fixtures/r/flake.nix
              ];
            };
            # keep-sorted end
          };
          failures = lib.debug.runTests tests;
          # A consumer's `files` check compares against files in its repo, which fixtures don't have.
          fixtureChecks = lib.concatMapAttrs (
            name: flake:
            lib.mapAttrs' (check: lib.nameValuePair "fixture-${name}-${check}") (
              removeAttrs flake.checks.${system} [ "files" ]
              // {
                devshell = flake.devShells.${system}.default;
              }
              // lib.optionalAttrs (has flake.packages "site") {
                site = flake.packages.${system}.site;
              }
            )
          ) fixtures;
        in
        {
          checks = fixtureChecks // {
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
