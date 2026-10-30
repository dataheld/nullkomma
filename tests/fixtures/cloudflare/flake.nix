{
  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      nullkomma.cloudflare = {
        enable = true;
        worker = "fixture-site";
        domain = "example.org";
        name = "www";
      };
      perSystem =
        { pkgs, ... }:
        {
          packages.site = pkgs.runCommand "site" { } "cp -r ${./site} $out";
        };
    };
}
