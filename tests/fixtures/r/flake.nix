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
      # Shared development tools belong in DESCRIPTION's Config/Needs/* fields.
      # Allow Remotes: and CRAN packages missing from nixpkgs:
      # nullkomma.r.allowOffNixpkgs = true;
      # Add committed startup files and instructions for non-Nix collaborators:
      # nullkomma.r-non-nix.enable = true;
    };
}
