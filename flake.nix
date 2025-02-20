{
  description = "nullkomma";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    # keep-sorted start
    flake-checker.url = "https://flakehub.com/f/DeterminateSystems/flake-checker/0.2.4.tar.gz";
    flake-iter.url = "https://flakehub.com/f/DeterminateSystems/flake-iter/0.1.92.tar.gz";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.1.5.tar.gz";
    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.102.tar.gz";
    format.url = "path:./format";
    # keep-sorted end
  };

  outputs = {
    self,
    nixpkgs,
    flake-checker,
    flake-iter,
    flake-schemas,
    flake-utils,
    format,
    ...
  }: 
    let
      systemOutputs = flake-utils.lib.eachDefaultSystem (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          formatting = format.checks.${system}.formatting;
          devShells.default = pkgs.mkShell {
              packages = [
                # keep-sorted start
                flake-checker.packages.${system}.default
                flake-iter.packages.${system}.default
                format.formatter.${system}
                pkgs.git
                pkgs.gnumake
                pkgs.nixd
                # keep-sorted end
              ];
            };
          formatter = format.formatter.${system};
        }
      );
      universalOutputs = {
        schemas = flake-schemas.schemas;
      };
    in
    systemOutputs // universalOutputs;
}
