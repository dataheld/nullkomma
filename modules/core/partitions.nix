# Inputs only for development, such as a private brand, go in
# `partitions.dev.extraInputsFlake`, so consumers never lock or fetch them.
# Per-system outputs then come from the `dev` partition;
# flake-level outputs, such as `lib`, cannot depend on those inputs.
{ inputs, ... }:
let
  devPartition =
    { config, lib, ... }:
    {
      key = "nullkomma#devPartition";
      imports = [ inputs.flake-parts.flakeModules.partitions ];
      partitionedAttrs = lib.mkIf (config.partitions ? dev) (
        # flake-parts declares `formatter` outside `transposition`.
        lib.mapAttrs (_: _: lib.mkDefault "dev") (config.transposition // { formatter = { }; })
      );
    };
in
{
  imports = [ devPartition ];
  framework.imports = [ devPartition ];
}
