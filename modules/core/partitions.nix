# Inputs only for development, such as a private brand, go in
# `partitions.dev.extraInputsFlake`, so consumers never lock or fetch them.
# Outputs for development then come from the `dev` partition.
{ inputs, ... }:
let
  devPartition =
    { config, lib, ... }:
    {
      key = "nullkomma#devPartition";
      imports = [ inputs.flake-parts.flakeModules.partitions ];
      partitionedAttrs = lib.mkIf (config.partitions ? dev) (
        lib.genAttrs [
          "apps"
          "checks"
          "devShells"
          "formatter"
          "packages"
          "processTrees"
          "schemas"
          "taskRunners"
        ] (_: lib.mkDefault "dev")
      );
    };
in
{
  imports = [ devPartition ];
  framework.imports = [ devPartition ];
}
