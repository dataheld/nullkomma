{
  flake.plugins.shell =
    { config, lib, ... }:
    {
      config.perSystem.treefmt.programs = lib.mkIf config.nullkomma.shell.enable {
        shellcheck.enable = lib.mkDefault true;
        shfmt.enable = lib.mkDefault true;
      };
    };
}
