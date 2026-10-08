# Extension point: a docs aspect (quarto, pkgdown, …) sets the site, deploy aspects read it.
{
  flake.flakeModules.default =
    { lib, ... }:
    {
      perSystem =
        { config, ... }:
        {
          options.nullkomma.site = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = null;
            description = "Static site (a directory with `index.html`); exposed as `packages.site`.";
          };
          config.packages = lib.mkIf (config.nullkomma.site != null) {
            site = config.nullkomma.site;
          };
        };
    };
}
