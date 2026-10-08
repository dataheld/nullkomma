{
  description = "An R project with batteries included by nullkomma";

  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
  # CRAN date lives in .Rprofile; packages and pinned Remotes live in DESCRIPTION.

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nullkomma.flakeModules.r ];
      # R packages come from DESCRIPTION; add dev-only ones here:
      # nullkomma.r.extraPackages = [ "devtools" ];
    };
}
