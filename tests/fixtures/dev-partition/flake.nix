{
  description = "A project with development-only inputs in a dev partition, as README describes";

  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } {
      partitions.dev = {
        extraInputsFlake = ./dev;
        module.nullkomma.gitignore = [ "/scratch/" ];
      };
    };
}
