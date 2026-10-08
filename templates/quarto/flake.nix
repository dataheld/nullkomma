{
  description = "A Quarto project with batteries included by nullkomma";

  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nullkomma.flakeModules.quarto
        # R chunks? Add the R aspect, too:
        # inputs.nullkomma.flakeModules.r
        # Deploy the site from CI:
        # inputs.nullkomma.flakeModules.cloudflare-pages
      ];
      # nullkomma.cloudflare-pages.project = "my-site";
    };
}
