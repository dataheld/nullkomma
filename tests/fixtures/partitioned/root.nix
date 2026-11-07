{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.partitions ];
  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];
  flake.schemas = inputs.nullkomma-schemas.schemas;
  partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
    "checks"
    "devShells"
    "formatter"
    "processTrees"
    "taskRunners"
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
