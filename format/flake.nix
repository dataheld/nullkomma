{
  description = "treefmt-nix";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    # keep-sorted start
    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.*";
    treefmt-nix.url = "github:numtide/treefmt-nix/3d0579f5cc93436052d94b73925b48973a104204";
    # keep-sorted end
  };

  outputs = {
    nixpkgs,
    flake-utils,
    treefmt-nix,
    self,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        formatter = treefmtEval.config.build.wrapper;
        formatting = treefmtEval.config.build.check self;
      }
    );
}
