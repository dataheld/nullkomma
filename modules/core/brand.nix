# A brand flake contributes privacy sections; R and Quarto can opt into its theme.
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
        description = "Optional brand flake exposing `lib.brand` (brand.yml) and optional `lib.privacy.<section>.<language>` Markdown paths. Enable `nullkomma.quarto.brand.enable` or `nullkomma.r.pkgdown.brand.enable` to apply its native theme and declarative `defaults.nullkomma.footer`; privacy sections join `nullkomma.privacy` independently of the footer.";
      };
      config.nullkomma.privacy.sections = lib.mkIf (brand != null) (
        lib.mapAttrs (name: markdown: {
          order = order.${name} or 500;
          inherit markdown;
        }) (brand.lib.privacy or { })
      );
    };
}
