# Producer/consumer contract: no renderer or deployment-provider dependencies here.
{
  flake.framework =
    { flake-parts-lib, lib, ... }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.site = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = ''
            Optional static-site derivation, independent of renderer or deployment provider.
            Its output root must contain `index.html`; producers must test that artifact.
            Exposed unchanged as `packages.site`; null adds no package.
            Configure one site per system (conflicting producers require explicit selection).
            Consumers requiring a site must reject null and validate additional requirements.
          '';
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
