{
  partitions.dev.module =
    { inputs, ... }:
    {
      perSystem =
        { harness, lib, ... }:
        let
          inherit (harness) nullkomma perSystem root;
          # The flake's own Nixpkgs, told apart from nullkomma's.
          own = inputs.nixpkgs // {
            legacyPackages = lib.mapAttrs (_: pkgs: pkgs // { own = true; }) inputs.nixpkgs.legacyPackages;
          };
          flakeInputs = {
            self = {
              outPath = root;
              inputs = flakeInputs;
            };
            nixpkgs = own;
          };
          ownPkgs =
            mkFlake: module:
            (perSystem (mkFlake { inputs = flakeInputs; } (module // { debug = true; })))
            ._module.args.pkgs.own or false;
        in
        {
          nullkomma.nix.unit.tests.testPkgsByEntryPoint = {
            expr = {
              mkFlake = ownPkgs nullkomma.lib.mkFlake { };
              flakeModule = ownPkgs inputs.flake-parts.lib.mkFlake {
                imports = [ nullkomma.flakeModules.default ];
              };
            };
            expected = {
              mkFlake = false;
              flakeModule = true;
            };
          };
        };
    };
}
