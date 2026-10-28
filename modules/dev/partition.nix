# Dogfooding and tests are evaluated only in the `dev` partition.
# Schemas come from the shared framework imported by dogfooding.
# Dev-only inputs live in ../../dev/flake.nix, outside consumers' flake.lock.
{
  partitions.dev.extraInputsFlake = ../../dev;
  # The root lacks the nix plugin that routes `tests` for consumers.
  partitionedAttrs.tests = "dev";
}
