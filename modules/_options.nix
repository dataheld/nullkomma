# nullkomma's options, evaluated the way https://flake.parts renders listed modules:
# without `pkgs`, `systems` or `self`, so computed defaults need a `defaultText`.
{
  flake-parts,
  lib,
  module,
  nixpkgs,
}:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  unavailable = what: throw "${what} is not available when rendering option docs; add a `defaultText`.";
in
(flake-parts.lib.evalFlakeModule
  {
    inputs = {
      inherit nixpkgs;
      self.outPath = unavailable "`self.outPath`";
    };
  }
  {
    imports = [
      module
      (
        { flake-parts-lib, ... }:
        {
          options.perSystem = flake-parts-lib.mkPerSystemOption {
            _module.args.pkgs = lib.mapAttrs (name: _: unavailable "`pkgs.${name}`") pkgs // {
              _type = "pkgs";
              inherit lib;
              inherit (pkgs) formats;
            };
          };
        }
      )
    ];
    systems = [ (unavailable "`systems`") ];
  }
).options
