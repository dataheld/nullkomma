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
        cloudflare = {
          enable = true;
          domain = "maxheld.de";
        };
        gitignore = [ ".claude/" ];
        quarto = {
          enable = true;
          brand.enable = true;
        };
        lint.jscpd.ignore = [ "tests/snapshots/**" ];
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
      perSystem.nullkomma.files = {
        # Tracked and hand-edited.
        ".vscode/settings.json".mode = "source";
        ".vscode/extensions.json".mode = "source";
        ".github/workflows/push.yml".enable = false;
        "README.md" = {
          commentPrefix = "<!--";
          commentSuffix = " -->";
          # Plugins with options beyond `enable`: only their configs have blank lines.
          sections = lib.mapAttrs (_: text: "```nix\n${text}```\n") (
            lib.filterAttrs (_: lib.hasInfix "\n\n") inputs.self.lib.configs
          );
        };
      };
    };
}
