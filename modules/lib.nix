{ inputs, lib, ... }:
{
  flake.lib = {
    importTree = import ../lib/import-tree.nix lib;
    r = import ../lib/r.nix { inherit lib; };
    # `flake-parts.lib.mkFlake`, with `flakeModules.default` already imported.
    mkFlake =
      args: module:
      inputs.flake-parts.lib.mkFlake args {
        imports = [
          inputs.self.flakeModules.default
          module
        ];
      };
  };
}
