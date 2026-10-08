{
  description = "An R project with batteries included by nullkomma";

  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
  # Pin R and CRAN to a date (adds one input to flake.lock):
  # inputs.nullkomma.inputs.nixpkgs-r.url = "github:rstats-on-nix/nixpkgs/2026-01-05";

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nullkomma.flakeModules.r ];
      # R packages come from DESCRIPTION; add dev-only ones here:
      # nullkomma.r.extraPackages = [ "devtools" ];
    };
}
