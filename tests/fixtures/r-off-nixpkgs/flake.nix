{
  description = "An R project with packages nixpkgs does not provide";

  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      nullkomma.r.enable = true;
      nullkomma.r.hashes.digest = "sha256-gsTRSZlLikqa+TD1qOR0IIKZNavtQfP5Aw6UtqSPAyE=";
    };
}
