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
      imports = [
        inputs.flake-parts.flakeModules.partitions
        inputs.nullkomma-schemas.flakeModules.default
      ];
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
        "checks"
        "formatter"
        "tests"
      ] (_: "dev");
      partitions.dev = {
        extraInputsFlake = ./dev;
        module =
          { inputs, ... }:
          {
            imports = [ inputs.nullkomma.flakeModules.default ];
            disabledModules = [ { key = "nullkomma#devPartition"; } ];
          };
      };
      perSystem =
        { pkgs, ... }:
        {
          packages.hello = pkgs.writeShellScriptBin "hello" "echo hello";
        };
    };
}
