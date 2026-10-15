# nullkomma's curated Nixpkgs pin is the default `pkgs`. Consumers expose it as
# their own input (`nixpkgs.follows = "nullkomma/nixpkgs"`, as in the template),
# so lock tooling such as flake-checker sees the Nixpkgs they actually use.
{ inputs, ... }:
{
  framework =
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
