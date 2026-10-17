{
  plugins.r =
    { config, lib, ... }:
    let
      cfg = config.nullkomma.r;
      brand = cfg.pkgdown.brand;
      privacy = lib.evalModules {
        modules = [
          (import ../../core/privacy.nix).framework
          (brand.flakeModules.privacy or { })
        ];
      };
    in
    {
      options.nullkomma.r.pkgdown.brand = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        example = lib.literalExpression "inputs.brand";
        description = "Optional brand flake exposing lib.brand (brand.yml), optional lib.footer (HTML), and optional flakeModules.privacy. Wires Bootstrap 5, the brand theme, footer and privacy sections into local and sandboxed pkgdown builds; no brand input is added by nullkomma.";
      };
      config = lib.mkIf (cfg.enable && cfg.pkgdown.enable && brand != null) {
        nullkomma.privacy.sections = privacy.config.nullkomma.privacy.sections;
        nullkomma.r.pkgdown.config = {
          template = {
            bootstrap = lib.mkDefault 5;
            bslib.brand = lib.mkDefault brand.lib.brand;
          };
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
        };
      };
    };
}
