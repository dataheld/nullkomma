{
  description = "A project that other flakes consume, with nullkomma only in dev/flake.nix, as README describes";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605.*";
    flake-parts = {
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.flake-parts.flakeModules.partitions ];
      partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
        "checks"
        "devShells"
        "formatter"
        "packages"
        "processTrees"
        "taskRunners"
        "tests"
      ] (_: "dev");
      partitions.dev = {
        extraInputsFlake = ./dev;
        module =
          { inputs, ... }:
          {
            imports = [ inputs.nullkomma.flakeModules.default ];
          };
      };
    };
}
