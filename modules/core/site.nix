# Extension point for modules that provide a static site.
{
  flake.plugins.base =
    { flake-parts-lib, lib, ... }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.site = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Static site (a directory with `index.html`); exposed as `packages.site`.";
        };
      };
      config.perSystem =
        { config, ... }:
        {
          config.packages = lib.mkIf (config.nullkomma.site != null) {
            site = config.nullkomma.site;
          };
        };
    };
}
