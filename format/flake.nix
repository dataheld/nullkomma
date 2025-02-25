{
  description = "treefmt-nix";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    # keep-sorted start
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.1.*";
    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.*";
    treefmt-nix.url = "github:numtide/treefmt-nix/3d0579f5cc93436052d94b73925b48973a104204";
    # keep-sorted end
  };

  outputs = {
    nixpkgs,
    flake-utils,
    flake-schemas,
    treefmt-nix,
    self,
  }: let
    universalOutputs = {
      schemas = flake-schemas.schemas;
    };
    systemOutputs = flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in {
        formatter = treefmtEval.config.build.wrapper;
        checks = {
          formatting = treefmtEval.config.build.check self;
        };
      }
    );
  in
    universalOutputs // systemOutputs;
}
