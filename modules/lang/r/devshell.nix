{
  flake.flakeModules.r.perSystem =
    { config, ... }:
    {
      nullkomma.devshell.packages = [ config.nullkomma.r.package ];
    };
}
