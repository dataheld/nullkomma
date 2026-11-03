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
      perSystem.nullkomma.files = {
        # The workspace editor settings are tracked and hand-edited.
        ".vscode/settings.json".mode = "source";
        ".vscode/extensions.json".mode = "source";
        "README.md" = {
          commentPrefix = "<!--";
          commentSuffix = " -->";
          sections = lib.genAttrs [
            "agents"
            "cloudflare"
            "github"
            "nix"
            "quarto"
            "r"
            "shell"
          ] (plugin: "```nix\n${inputs.self.lib.configs.${plugin}}```\n");
        };
      };
    };
}
