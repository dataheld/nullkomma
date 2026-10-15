{
  description = "An R project with batteries included by nullkomma";

  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      nullkomma.r.enable = true;
      # R packages come from DESCRIPTION, locked in pkg.lock by `nix run .#r-lock`.
      # Add dev-only ones here:
      # nullkomma.r.extraPackages = [ "devtools" ];
      # Allow Remotes: and CRAN packages missing from nixpkgs:
      # nullkomma.r.allowOffNixpkgs = true;
      # Write an .Rprofile with the matching PPM snapshot for non-Nix collaborators:
      # nullkomma.r.rprofile.enable = true;
    };
}
