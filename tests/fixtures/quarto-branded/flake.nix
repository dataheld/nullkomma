{
  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      nullkomma.brand.lib.brand = ../site-brand/brand.yml;
      nullkomma.quarto-brand.enable = true;
      nullkomma.quarto.extensions.greeting = ./_greeting;
      nullkomma.lint.markdown.MD041 = false;
      nullkomma.privacy.sections.local.markdown = {
        en = ./_privacy/local.en.md;
        de = ./_privacy/local.de.md;
      };
    };
}
