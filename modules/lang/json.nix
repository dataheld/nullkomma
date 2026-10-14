{
  flake.plugins.json =
    { config, lib, ... }:
    {
      options.nullkomma.json.enable = lib.mkEnableOption "JSON project integration";
      config.perSystem.treefmt.programs.jsonfmt.enable = lib.mkDefault config.nullkomma.json.enable;
    };
}
