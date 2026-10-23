# Inputs only nullkomma's own development needs, loaded by the `dev` partition
# (modules/dev/partition.nix), so they never land in consumers' flake.lock.
{
  inputs.brand.url = "https://flakehub.com/f/dataheld/brand/*";
  outputs = _: { };
}
