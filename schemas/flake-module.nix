# For a root with nullkomma only in its `dev` partition.
# The CLI looks up `.#name` in every output whose schema has a fitting role,
# even after a match, so it must not need the partition to rule out a name.
flake-schemas:
{
  config,
  lib,
  partitionStack,
  ...
}:
let
  named =
    output: name:
    lib.genAttrs config.systems (system: {
      ${name} = config.partitions.dev.module.flake.${output}.${system}.${name};
    });
in
{
  flake = lib.optionalAttrs (partitionStack == [ ]) {
    schemas = import ./. flake-schemas;
    devShells = named "devShells" "default";
    processTrees = named "processTrees" "dev";
    taskRunners = named "taskRunners" "default";
  };
}
