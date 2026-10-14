{
  flake.plugins.keepSorted =
    { config, lib, ... }:
    {
      config.perSystem.treefmt.programs.keep-sorted.enable = lib.mkIf config.nullkomma.keepSorted.enable (
        lib.mkDefault true
      );
    };
}
