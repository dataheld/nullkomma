{
  description = "An R package output without development dependencies";

  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      nullkomma.r = {
        enable = true;
        root = ../r;
      };
      perSystem =
        { pkgs, ... }:
        {
          # The package only imports stats, which ships with R. Suggests and
          # Config/Needs/* belong to the development environment, not this output.
          packages.default = pkgs.rPackages.buildRPackage {
            pname = "nullkommafixture";
            version = "0.0.1";
            src = ../r;
            nativeBuildInputs = [ pkgs.rPackages.roxygen2 ];
            preInstall = ''
              Rscript --vanilla -e 'roxygen2::roxygenise()'
            '';
          };
        };
    };
}
