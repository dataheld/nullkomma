# nullkomma uses nullkomma: this repo is a Quarto site (README as index.qmd).
{
  partitions.dev.module =
    { inputs, ... }:
    {
      imports = [
        inputs.self.flakeModules.default
        inputs.self.flakeModules.quarto
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
      };
      perSystem =
        { pkgs, ... }:
        {
          nullkomma.devshell.packages = [ pkgs.fh ];
        };
    };
}
