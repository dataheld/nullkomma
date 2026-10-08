{
  description = "Fixture: Quarto site with R chunks, deployed to Cloudflare Pages";

  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      imports = with inputs.nullkomma.flakeModules; [
        cloudflare-pages
        quarto
        r
      ];
      nullkomma.cloudflare-pages.project = "nullkomma-fixture";
    };
}
