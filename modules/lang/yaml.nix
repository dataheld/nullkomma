{
  flake.plugins.yaml =
    { config, lib, ... }:
    {
      options.nullkomma.yaml.enable = lib.mkEnableOption "YAML project integration";
      config.perSystem.treefmt.programs.yamlfmt.enable = lib.mkDefault config.nullkomma.yaml.enable;
    };
}
