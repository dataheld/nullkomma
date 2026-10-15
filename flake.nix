{
  description = "Opinionated, batteries-included, extra-DRY Nix boilerplate";

  # Every input lands in every consumer's flake.lock, so keep this list short.
  # Tools come from nixpkgs; schemas describe both our and consumers' outputs.
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605.*";
    # Override this input to select another R/CRAN package set.
    nixpkgs-r.follows = "nixpkgs";
    flake-parts = {
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.5.*";
    treefmt-nix = {
      url = "https://flakehub.com/f/numtide/treefmt-nix/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    up = {
      url = "https://flakehub.com/f/DeterminateSystems/up/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-schemas.follows = "flake-schemas";
    };
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    terraform-providers-bin = {
      url = "github:nix-community/nixpkgs-terraform-providers-bin";
      flake = false;
    };
  };

  # Dendritic: every file under ./modules is a flake-parts module.
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = import ./lib/import-tree.nix inputs.nixpkgs.lib ./modules;
    };
}
