# Inputs only nullkomma's own development needs, loaded by the `dev` partition
# (modules/dev/partition.nix), so they never land in consumers' flake.lock.
{
  inputs.nix-unit.url = "github:nix-community/nix-unit";
  outputs = _: { };
}
