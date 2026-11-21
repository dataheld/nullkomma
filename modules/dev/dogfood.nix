# nullkomma uses nullkomma for its own development environment.
{
  partitions.dev.module =
    { inputs, lib, ... }:
    {
      imports = [
        inputs.self.flakeModules.default
      ];
      nullkomma = {
        generatedPaths = [ "tests/fixtures/r/tests/testthat/_snaps/**" ];
        brand = inputs.brand;
        cloudflareSite = {
          enable = true;
          domain = "maxheld.de";
        };
        gitignore = [ ".claude/" ];
        quarto = {
          enable = true;
          brand.enable = true;
        };
        lint.jscpd.ignore = [
          "tests/fixtures/*/flake.nix"
          "tests/snapshots/**"
          # Copied into AGENTS.md, which must keep nullkomma's lines.
          "modules/tools/_agents/AGENTS.md"
          # Shares the checkout and Nix setup steps with ci.yml.
          ".github/workflows/push.yml"
        ];
        lint.markdown = {
          MD013 = false;
          MD028 = false;
        };
        lint.typos = {
          default.extend-words.fnd = "fnd";
          type.nullkomma-lint-tests = {
            extend-glob = [
              "*.test.nix"
              "dogfood.nix"
            ];
            extend-words.teh = "teh";
          };
        };
      };
      perSystem.nullkomma = {
        # Tracked and hand-edited.
        links.".vscode/settings.json".enable = false;
        links.".vscode/extensions.json".enable = false;
        files.".github/workflows/push.yml".enable = false;
        # Plugins with options beyond `enable`: only their configs have blank lines.
        files."README.md".text = lib.concatStrings (
          lib.attrValues (lib.filterAttrs (_: lib.hasInfix "\n\n") inputs.self.lib.configs)
        );
      };
    };
}
