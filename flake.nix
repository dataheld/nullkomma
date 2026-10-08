{
  description = "Opinionated, batteries-included, extra-DRY Nix boilerplate";

  # Every input lands in every consumer's flake.lock, so keep this list short.
  # Tools come from nixpkgs; dev-only inputs live in ./dev/flake.nix.
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605.*";
    # Knob: R version and CRAN snapshot. Free unless a consumer overrides it, e.g.
    # inputs.nullkomma.inputs.nixpkgs-r.url = "github:rstats-on-nix/nixpkgs/2026-01-05";
    nixpkgs-r.follows = "nixpkgs";
    flake-parts = {
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "https://flakehub.com/f/numtide/treefmt-nix/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Dendritic: every file under ./modules is a flake-parts module.
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = import ./lib/import-tree.nix inputs.nixpkgs.lib ./modules;
    };
}
