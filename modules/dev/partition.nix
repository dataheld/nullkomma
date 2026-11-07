# Dogfooding and tests are evaluated only in the `dev` partition.
# Dev-only inputs live in ../../dev/flake.nix, outside consumers' flake.lock.
{ inputs, lib, ... }:
{
  partitions.dev.extraInputsFlake = ../../dev;
  flake.schemas = import ../../schemas inputs.flake-schemas;
  # The root lacks the framework and plugins that add these outputs.
  partitionedAttrs = lib.genAttrs [
    "legacyPackages"
    "processTrees"
    "taskRunners"
    "tests"
  ] (_: "dev");
}
