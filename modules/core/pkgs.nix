# `lib.mkFlake` makes nullkomma's curated Nixpkgs pin the default `pkgs`. Consumers expose it
# as their own input (`nixpkgs.follows = "nullkomma/nixpkgs"`, as in the template),
# so lock tooling such as flake-checker sees the Nixpkgs they actually use.
# Elsewhere, as in a `dev` partition of a flake that does not use `lib.mkFlake`,
# `pkgs` is flake-parts' default: the flake's own `nixpkgs` input.
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
    };
  mkFlake.perSystem =
    { lib, system, ... }:
    {
      _module.args.pkgs = lib.mkDefault inputs.nixpkgs.legacyPackages.${system};
    };
}
