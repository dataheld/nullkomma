{ inputs, ... }:
{
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
  partitions.dev.module =
    { inputs, ... }:
    {
      imports = [ inputs.nullkomma.flakeModules.default ];
      disabledModules = [ { key = "nullkomma#devPartition"; } ];
    };
  perSystem =
    { pkgs, ... }:
    {
      packages.hello = pkgs.writeShellScriptBin "hello" "echo hello";
    };
}
