# Inputs only for development, such as a private brand, go in
# `partitions.dev.extraInputsFlake`, so consumers never lock or fetch them.
# Per-system outputs then come from the `dev` partition;
# flake-level outputs, such as `lib`, cannot depend on those inputs.
# The flake-parts that evaluates the flake imports its own partitions module:
# nullkomma's in `lib.mkFlake`, the consumer's in its own `mkFlake`.
# A second copy, from another pin, would declare the same options twice.
{ inputs, ... }:
let
  inherit (inputs.flake-parts.flakeModules) partitions;
  devPartition =
    {
      config,
      lib,
      options,
      ...
    }:
    {
      key = "nullkomma#devPartition";
      config = lib.optionalAttrs (options ? partitionedAttrs) {
        partitionedAttrs = lib.mkIf (config.partitions ? dev) (
          # flake-parts declares `formatter` outside `transposition`.
          lib.mapAttrs (_: _: lib.mkDefault "dev") (config.transposition // { formatter = { }; })
        );
      };
    };
in
{
  imports = [
    partitions
    devPartition
  ];
  framework.imports = [ devPartition ];
  mkFlake.imports = [ partitions ];
}
