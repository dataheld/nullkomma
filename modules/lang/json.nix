{
  flake.plugins.json =
    { config, lib, ... }:
    {
      config.perSystem.treefmt.programs.jsonfmt.enable = lib.mkIf config.nullkomma.json.enable (
        lib.mkDefault true
      );
    };
}
