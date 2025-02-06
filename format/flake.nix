# copied from https://github.com/numtide/treefmt-nix
{
  description = "treefmt-nix";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs = {
    self,
    nixpkgs,
    systems,
    treefmt-nix,
  }: let
    # Small tool to iterate over each systems, now allowing unfree packages
    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true; # Allows unfree packages
          };
        in
          f pkgs
      );
    # Eval the treefmt modules from ./treefmt.nix
    treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
  in {
    # for `nix fmt`
    formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
    # for `nix flake check`
    checks = eachSystem (pkgs: {
      formatting = treefmtEval.${pkgs.system}.config.build.check self;
    });
  };
}
