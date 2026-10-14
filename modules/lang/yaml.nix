{
  flake.plugins.yaml =
    { config, lib, ... }:
    {
      config.perSystem.treefmt.programs.yamlfmt.enable = lib.mkIf config.nullkomma.yaml.enable (
        lib.mkDefault true
      );
    };
}
