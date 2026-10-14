{
  description = "A project with batteries included by nullkomma";

  inputs.nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";

  outputs = inputs: inputs.nullkomma.lib.mkFlake { inherit inputs; } { };
}
