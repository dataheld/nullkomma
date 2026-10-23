{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      inherit (config.nullkomma) brand;
    in
    {
      config.nullkomma.r.pkgdown.config = lib.mkIf (cfg.enable && cfg.pkgdown.enable && brand != null) {
        template.bslib.brand = lib.mkDefault brand.lib.brand;
        template.light-switch = lib.mkDefault true;
      };
    };
}
