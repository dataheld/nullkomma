# Everything nullkomma needs for its own development (dogfooding, schemas, tests)
# is evaluated in the `dev` partition, with extra inputs from ./dev/flake.nix that
# consumers never fetch nor lock.
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
    "schemas"
  ] (_: "dev");
}
