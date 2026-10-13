{
  description = "An R project with batteries included by nullkomma";

  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
  # R packages come from DESCRIPTION (including pinned Remotes: and version constraints).
  # To generate an .Rprofile with matching PPM snapshot for non-Nix collaborators:
  # nullkomma.r.rprofile.enable = true;

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nullkomma.flakeModules.r ];
      # R packages come from DESCRIPTION; add dev-only ones here:
      # nullkomma.r.extraPackages = [ "devtools" ];
    };
}
