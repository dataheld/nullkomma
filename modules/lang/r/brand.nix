{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      inherit (config.nullkomma) brand;
    in
    {
      config.nullkomma.r.pkgdown.config = lib.mkIf (cfg.enable && cfg.pkgdown.enable && brand != null) {
        template.package = lib.mkDefault "nullkommabrand";
      };
    };
}
