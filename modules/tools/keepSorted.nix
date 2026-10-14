{
  flake.plugins.keepSorted =
    { config, lib, ... }:
    {
      options.nullkomma.keepSorted.enable = lib.mkEnableOption "keep-sorted integration";
      config.perSystem.treefmt.programs.keep-sorted.enable =
        lib.mkDefault config.nullkomma.keepSorted.enable;
    };
}
