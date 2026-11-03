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
    nullkomma = lib.genAttrs (config.flake.lib.defaultPlugins ++ [ "devShell" ]) (_: {
      enable = lib.mkDefault true;
    });
  };
  flake.lib = {
    defaultPlugins = [
      "agents"
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
      "typos"
      "vscode"
      "yaml"
    ];
    # Write one to `nix/<plugin>.nix` with
    # `nix eval --raw --inputs-from . nullkomma#lib.configs.<plugin> > nix/<plugin>.nix`.
    configs = import ./_configs.nix lib (lib.attrNames config.plugins) (
      import ./_options.nix {
        inherit lib;
        inherit (inputs) flake-parts nixpkgs;
        module = flakeModules.default;
      }
    );
    # Modules below a directory, e.g. `imports = importTree ./nix;` in a project's flake.
    importTree = import ../lib/import-tree.nix lib;
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
