# Consumers inherit output schemas without declaring another input.
{ inputs, ... }:
{
  framework =
    { lib, ... }:
    {
      options.flake = lib.mkOption {
        type = lib.types.submoduleWith {
          modules = [
            {
              options.schemas = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.raw;
                default = { };
                description = "[Flake schemas](https://github.com/DeterminateSystems/flake-schemas) describing this flake's outputs; add your own next to nullkomma's.";
              };
            }
          ];
        };
      };
      # A root reading these itself defines the same keys again in its `dev` partition.
      config.flake.schemas = lib.mapAttrs (_: lib.mkDefault) (import ../../schemas inputs.flake-schemas);
    };
}
