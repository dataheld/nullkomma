{
  description = "Schemas of nullkomma's outputs, for flakes with nullkomma only in a `dev` partition";

  inputs.flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.5.*";

  outputs =
    { flake-schemas, ... }:
    {
      schemas = import ./. flake-schemas;
    };
}
