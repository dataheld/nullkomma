{
  description = "dataheld-base";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    flake-checker.url = "https://flakehub.com/f/DeterminateSystems/flake-checker/0.2.4.tar.gz";
    flake-iter.url = "https://flakehub.com/f/DeterminateSystems/flake-iter/0.1.92.tar.gz";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.1.5.tar.gz";
  };

  outputs = {
    self,
    nixpkgs,
    flake-checker,
    flake-iter,
    flake-schemas
  }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in {
      schemas = flake-schemas.schemas;
      checks = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.runCommand "check" {} ''touch $out'';
      });
      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            flake-checker.packages.${pkgs.system}.default
            flake-iter.packages.${pkgs.system}.default
            gnumake
            nixpkgs-fmt
          ];
        };
      });
    };
}
