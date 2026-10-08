# Consumers need no nixpkgs input: nullkomma's curated pin is the default `pkgs`.
{ inputs, ... }:
{
  flake.flakeModules.default =
    { lib, ... }:
    {
      systems = lib.mkDefault [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      perSystem =
        { system, ... }:
        {
          _module.args.pkgs = lib.mkDefault inputs.nixpkgs.legacyPackages.${system};
        };
    };
}
