{ inputs, lib, ... }:
{
  flake.lib = {
    importTree = import ../lib/import-tree.nix lib;
    # `flake-parts.lib.mkFlake`, with `plugins.base` already imported.
    mkFlake =
      args: module:
      inputs.flake-parts.lib.mkFlake args {
        imports = [
          inputs.self.plugins.base
          module
        ];
      };
  };
}
