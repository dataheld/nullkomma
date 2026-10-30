# nullkomma uses nullkomma for its own development environment.
{
  partitions.dev.module =
    { inputs, ... }:
    {
      imports = [
        inputs.self.flakeModules.default
      ];
      nullkomma = {
        agents.skills.update-integration-matrix = ./_skills/update-integration-matrix;
        generatedPaths = [ "tests/fixtures/r/tests/testthat/_snaps/**" ];
        brand = inputs.brand;
        cloudflare = {
          enable = true;
          domain = "maxheld.de";
        };
        github = {
          workflows = {
            source = "./.github/workflows";
            ref = null;
          };
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
          MD041 = false;
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
      # The workspace editor settings are tracked and hand-edited.
      perSystem.nullkomma.files = {
        ".vscode/settings.json".mode = "source";
        ".vscode/extensions.json".mode = "source";
      };
    };
}
