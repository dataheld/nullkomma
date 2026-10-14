{
  flake.plugins.toml =
    { config, lib, ... }:
    {
      options.nullkomma.toml.enable = lib.mkEnableOption "TOML project integration";
      config.perSystem.treefmt.programs.toml-sort.enable = lib.mkDefault config.nullkomma.toml.enable;
    };
}
