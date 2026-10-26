# Dogfooding and tests are evaluated only in the `dev` partition.
# Schemas come from the shared framework imported by dogfooding.
# Dev-only inputs live in ../../dev/flake.nix, outside consumers' flake.lock.
{ inputs, lib, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.partitions ];
  partitions.dev.extraInputsFlake = ../../dev;
  partitionedAttrs = lib.genAttrs [
    "apps"
    "checks"
    "devShells"
    "formatter"
    "packages"
    "processTrees"
    "schemas"
    "taskRunners"
    "tests"
  ] (_: "dev");
}
