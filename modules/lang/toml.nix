{
  flake.plugins.toml =
    { config, lib, ... }:
    {
      config.perSystem.treefmt.programs.toml-sort.enable = lib.mkIf config.nullkomma.toml.enable (
        lib.mkDefault true
      );
    };
}
