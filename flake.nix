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
    nix-unit = {
      url = "github:nix-community/nix-unit/?tag=v2.24.1";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    treefmt-nix.url = "github:numtide/treefmt-nix/3d0579f5cc93436052d94b73925b48973a104204";
  };

  outputs =
    { flake-parts, self, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # keep-sorted start
        inputs.nix-unit.modules.flake.default
        inputs.treefmt-nix.flakeModule
        # keep-sorted end
      ];
      systems = [
        # keep-sorted start
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        # keep-sorted end
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
              pkgs.quartoMinimal
              self'.formatter
              # keep-sorted end
            ];
          };
          packages = {
            docs = pkgs.stdenv.mkDerivation {
              name = "nullkomma-docs";
              src = ./.;
              buildInputs = [ 
                pkgs.quartoMinimal
                pkgs.which
              ];
              HOME = "$TMPDIR";
              configurePhase = ''
                export HOME=$(mktemp -d)
              '';
              buildPhase = ''
                make render
              '';
              installPhase = ''
                mkdir $out
                mv _site $out
              '';
            };
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
          nix-unit = {
            inputs = {
              inherit (inputs)
                nixpkgs
                flake-parts
                nix-unit
                treefmt-nix
                ;
            };
            tests = {
              "test example system-specific" = {
                expr = "1";
                expected = "1";
              };
            };
          };
        };
      flake = {
        schemas = inputs.flake-schemas.schemas;
        templates = rec {
          base = {
            description = "nullkomma template";
            path = ./templates/base;
            welcomeText = ''
              Welcome to the nullkomma template
            '';
          };
          default = base;
        };
        tests = {
          "test example system-agnostic" = {
            expr = "2";
            expected = "2";
          };
          "test template welcome text" = {
            expr = self.templates.default.description;
            expected = "nullkomma template";
          };
        };
      };
    };
}
