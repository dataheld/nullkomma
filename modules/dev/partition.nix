# Dogfooding and tests are evaluated only in the `dev` partition.
# Dev-only inputs live in ../../dev/flake.nix, outside consumers' flake.lock.
{ inputs, lib, ... }:
{
  imports = [ (import ../../schemas/flake-module.nix inputs.flake-schemas) ];
  partitions.dev.extraInputsFlake = ../../dev;
  # The root lacks the framework and plugins that add these outputs.
  partitionedAttrs = lib.genAttrs [
    "legacyPackages"
    "tests"
  ] (_: "dev");
}
