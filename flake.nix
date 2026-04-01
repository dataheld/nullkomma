{
  description = "nullkomma";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2511.*";
    # keep-sorted start
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1.*";
    flake-checker = {
      # must use non-flakehub inputs,
      # b/c flake-checker was build with DetSys Secure Packages
      # which are not available without subscription
      inputs.nixpkgs.follows = "nixpkgs";
      url = "https://flakehub.com/f/DeterminateSystems/flake-checker/0.2.*";
    };
    # keep-sorted end
    flake-iter.url = "https://flakehub.com/f/DeterminateSystems/flake-iter/0.1.*";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
    };
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.3.*";
    nix-unit = {
      url = "github:nix-community/nix-unit/?tag=v2.24.1";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };
    treefmt-nix.url = "https://flakehub.com/f/numtide/treefmt-nix/0.1.*";
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
        "aarch64-linux"
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
          checks = {
            test-template-bad-readme =
              pkgs.runCommand "test-bad-readme"
                {
                  buildInputs = [
                    pkgs.nix
                  ];
                  __noChroot = true;
                  NIX_CONFIG = "experimental-features = nix-command flakes";
                }
                ''
                  mkdir -p $TMPDIR/home
                  export HOME=$TMPDIR/home
                  # cd $tmp
                  nix flake init --template ${self}#default
                  echo "bad _markdown*" > README.md
                  if ! nix flake check; then
                    touch $out
                  else
                    echo "Test failed: nix flake check succeeded unexpectedly"
                    exit 1
                  fi
                '';
            test-template-good-readme =
              pkgs.runCommand "test-good-readme"
                {
                  buildInputs = [
                    pkgs.nix
                  ];
                  __noChroot = true;
                  NIX_CONFIG = "experimental-features = nix-command flakes";
                }
                ''
                  mkdir -p $TMPDIR/home
                  export HOME=$TMPDIR/home
                  # cd $tmp
                  nix flake init --template ${self}#default
                  echo "good *markdown*" > README.md
                  if nix flake check; then
                    touch $out
                  else
                    echo "Test failed: nix flake check failed unexpectedly"
                    exit 1
                  fi
                '';
          };
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
              nativeBuildInputs = [
                pkgs.writableTmpDirAsHomeHook
              ];
              buildInputs = [
                pkgs.quartoMinimal
                pkgs.which
              ];
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
