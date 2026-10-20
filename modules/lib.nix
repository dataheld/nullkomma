{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake) flakeModules;
in
{
  # The framework and every plugin, with the default plugins enabled.
  flake.flakeModules.default = {
    imports = map (name: flakeModules.${name}) ([ "framework" ] ++ lib.attrNames config.plugins);
    nullkomma = lib.genAttrs (config.flake.lib.defaultPlugins ++ [ "devshell" ]) (_: {
      enable = lib.mkDefault true;
    });
  };
  flake.lib = {
    defaultPlugins = [
      "direnv"
      "flakehub"
      "git"
      "github"
      "gitleaks"
      "jscpd"
      "json"
      "keepSorted"
      "markdown"
      "neovim"
      "nix"
      "shell"
      "toml"
      "treefmt"
      "typos"
      "vscode"
      "yaml"
    ];
    mkFlake =
      args: module:
      inputs.flake-parts.lib.mkFlake args {
        imports = [
          flakeModules.default
          module
        ];
      };
  };
}
