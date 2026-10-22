# nullkomma uses nullkomma for its own development environment.
{
  partitions.dev.module =
    { inputs, ... }:
    {
      imports = [
        inputs.self.flakeModules.default
        inputs.brand.flakeModules.default
      ];
      nullkomma = {
        github = {
          workflows = {
            source = "./.github/workflows";
            ref = null;
          };
          ci.inputs.visibility = "public";
        };
        gitignore = [ ".claude/" ];
        quarto.enable = true;
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
