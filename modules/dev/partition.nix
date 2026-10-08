# Dogfooding and tests are evaluated only in the `dev` partition.
# Schemas come from the shared default aspect imported by dogfooding.
{ inputs, lib, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.partitions ];
  partitionedAttrs = lib.genAttrs [
    "apps"
    "checks"
    "devShells"
    "formatter"
    "packages"
    "schemas"
  ] (_: "dev");
}
