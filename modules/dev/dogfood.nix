# nullkomma uses nullkomma for its own development environment.
{
  partitions.dev.module =
    { inputs, lib, ... }:
    {
      imports = [
        inputs.self.framework
      ]
      ++ lib.attrValues inputs.self.plugins
      ++ [
        {
          nullkomma =
            lib.genAttrs inputs.self.lib.defaultPlugins (_: {
              enable = lib.mkDefault true;
            })
            // {
              devshell.enable = lib.mkDefault true;
            };
        }
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
    };
}
