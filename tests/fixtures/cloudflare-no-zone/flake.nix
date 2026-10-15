{
  inputs = {
    nullkomma.url = "path:../../..";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };
  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      nullkomma.cloudflare = {
        enable = true;
        projectName = "fixture-site";
        domain = "www.example.org";
      };
      perSystem = { pkgs, ... }: { nullkomma.site = pkgs.emptyDirectory; };
    };
}
