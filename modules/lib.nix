{ inputs, lib, ... }:
{
  flake.lib = {
    importTree = import ../lib/import-tree.nix lib;
    defaultPlugins = [
      "direnv"
      "flakehub"
      "git"
      "github"
      "json"
      "keepSorted"
      "markdown"
      "neovim"
      "nix"
      "shell"
      "toml"
      "treefmt"
      "vscode"
      "yaml"
    ];
    # flake-parts module: the framework and every plugin, with the default plugins enabled.
    defaults = {
      imports = [ inputs.self.framework ] ++ lib.attrValues inputs.self.plugins;
      nullkomma = lib.genAttrs (inputs.self.lib.defaultPlugins ++ [ "devshell" ]) (_: {
        enable = lib.mkDefault true;
      });
    };
    mkFlake =
      args: module:
      inputs.flake-parts.lib.mkFlake args {
        imports = [
          inputs.self.lib.defaults
          module
        ];
      };
  };
}
