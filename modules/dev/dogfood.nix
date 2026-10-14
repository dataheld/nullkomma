# nullkomma uses nullkomma for its own development environment.
{
  partitions.dev.module =
    { inputs, ... }:
    {
      imports = [ inputs.self.plugins.base ];
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
    };
}
