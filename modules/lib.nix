{ inputs, lib, ... }:
{
  flake.lib = {
    importTree = import ../lib/import-tree.nix lib;
    defaultPlugins = [
      "direnv"
      "editor"
      "flakehub"
      "git"
      "github"
      "json"
      "keepSorted"
      "markdown"
      "nix"
      "shell"
      "toml"
      "treefmt"
      "yaml"
    ];
    # Import definitions separately from the default plugin selection.
    mkFlake =
      args: module:
      inputs.flake-parts.lib.mkFlake args {
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
          module
        ];
      };
  };
}
