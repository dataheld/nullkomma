{
  flake.plugins.typos =
    { config, lib, ... }:
    {
      config.perSystem.treefmt.programs.typos.enable = lib.mkIf config.nullkomma.typos.enable (
        lib.mkDefault true
      );
    };
}
