{
  framework =
    { flake-parts-lib, lib, ... }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption {
        options.nullkomma.site = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Static assets directory containing `index.html`, exported as `packages.site`. Any builder may set it and any publisher may consume it.";
        };
      };
      config.perSystem =
        { config, ... }:
        {
          packages = lib.mkIf (config.nullkomma.site != null) {
            site = config.nullkomma.site;
          };
        };
    };
}
