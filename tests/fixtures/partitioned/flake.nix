{
  description = "A flake that others consume, with nullkomma only in its `dev` partition";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605.*";
    flake-parts = {
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nullkomma-schemas.url = "https://flakehub.com/f/dataheld/nullkomma/*?dir=schemas";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./root.nix ];
      partitions.dev.extraInputsFlake = ./dev;
    };
}
