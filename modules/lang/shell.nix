{
  flake.plugins.shell =
    { config, lib, ... }:
    {
      options.nullkomma.shell.enable = lib.mkEnableOption "shell script integration";
      config.perSystem.treefmt.programs = {
        shellcheck.enable = lib.mkDefault config.nullkomma.shell.enable;
        shfmt.enable = lib.mkDefault config.nullkomma.shell.enable;
      };
    };
}
