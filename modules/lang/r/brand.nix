{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      inherit (config.nullkomma) brand;
    in
    {
      config.nullkomma.r.pkgdown.config = lib.mkIf (cfg.enable && cfg.pkgdown.enable && brand != null) (
        {
          template.bslib.brand = lib.mkDefault brand.lib.brand;
        }
        // lib.optionalAttrs (brand.lib ? footer) {
          footer = {
            structure.left = lib.mkDefault "brand";
            components.brand = lib.mkDefault (
              # pkgdown already supplies the outer footer element.
              builtins.replaceStrings [ "<footer" "</footer>" ] [ "<div" "</div>" ] (
                builtins.readFile brand.lib.footer
              )
            );
          };
        }
      );
    };
}
