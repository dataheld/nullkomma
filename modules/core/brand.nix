# A brand flake themes the project's sites and contributes privacy sections;
# nullkomma adds no brand input itself.
{
  framework =
    { config, lib, ... }:
    let
      inherit (config.nullkomma) brand;
      # Imports cannot depend on config, so the brand's privacy module is evaluated on its own.
      privacy = lib.evalModules {
        modules = [
          (import ./privacy.nix).framework
          (brand.flakeModules.privacy or { })
        ];
      };
    in
    {
      options.nullkomma.brand = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        example = lib.literalExpression "inputs.brand";
        description = "Optional brand flake exposing `lib.brand` (brand.yml) and optional `flakeModules.privacy`. Quarto and pkgdown apply its native theme and declarative `defaults.nullkomma.footer`; optional `lib.footer` HTML remains supported for older brands. Privacy sections join `nullkomma.privacy` independently of the footer.";
      };
      config.nullkomma.privacy.sections = lib.mkIf (
        brand != null
      ) privacy.config.nullkomma.privacy.sections;
    };
}
