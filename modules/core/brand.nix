# A brand flake contributes privacy sections, and `quarto-brand` and `r-brand`
# theme sites with it; nullkomma adds no brand input itself.
{
  framework =
    { config, lib, ... }:
    let
      inherit (config.nullkomma) brand;
      # The controller opens a policy, email contact follows it and data subject
      # rights close it.
      order = {
        controller = 100;
        email = 150;
        rights = 900;
      };
    in
    {
      options.nullkomma.brand = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
        example = lib.literalExpression "inputs.brand";
        description = "Optional brand flake exposing `lib.brand` (brand.yml) and optional `lib.privacy.<section>.<language>` Markdown paths. The `quarto-brand` and `r-brand` plugins apply its native theme and declarative `defaults.nullkomma.footer` to Quarto and pkgdown sites; privacy sections join `nullkomma.privacy` independently of the footer.";
      };
      config.nullkomma.privacy.sections = lib.mkIf (brand != null) (
        lib.mapAttrs (name: markdown: {
          order = order.${name} or 500;
          inherit markdown;
        }) (brand.lib.privacy or { })
      );
    };
}
