{
  description = "nullkomma";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2411.*";
    # keep-sorted start
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1.*";
    flake-checker.url = "https://flakehub.com/f/DeterminateSystems/flake-checker/0.2.*";
    flake-iter.url = "https://flakehub.com/f/DeterminateSystems/flake-iter/0.1.*";
    # keep-sorted end
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
    };
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.1.*";
    treefmt-nix.url = "github:numtide/treefmt-nix/3d0579f5cc93436052d94b73925b48973a104204";
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # keep-sorted start
        inputs.treefmt-nix.flakeModule
        # keep-sorted end
      ];
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      perSystem =
        {
          inputs',
          pkgs,
          self',
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            packages = [
              # keep-sorted start
              inputs'.fh.packages.default
              inputs'.flake-checker.packages.default
              inputs'.flake-iter.packages.default
              pkgs.git
              pkgs.gnumake
              pkgs.nixd
              self'.formatter
              # keep-sorted end
            ];
          };
          treefmt = {
            programs = {
              # keep-sorted start
              actionlint.enable = true;
              beautysh.enable = true;
              black.enable = true;
              cmake-format.enable = true;
              deadnix.enable = true;
              hclfmt.enable = true;
              isort.enable = true;
              jsonfmt.enable = true;
              keep-sorted.enable = true;
              mdformat.enable = true;
              nixfmt.enable = true;
              prettier.enable = true;
              shellcheck.enable = true;
              shfmt.enable = true;
              sqlfluff.enable = true;
              toml-sort.enable = true;
              yamlfmt.enable = true;
              # keep-sorted end
            };
          };
          packages.default = pkgs.hello;
        };
      flake = {
        schemas = inputs.flake-schemas.schemas;
        templates = {
          default = {
            description = "nullkomma template";
            path = ./template;
            welcomeText = ''
              Welcome to the nullkomma template!
            '';
          };
        };
      };
    };
}
