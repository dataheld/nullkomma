# Inputs only nullkomma's own development needs, loaded by the `dev` partition
# (modules/dev/partition.nix), so they never land in consumers' flake.lock.
{
  # shortcut: archived; dataheld/maxheld supersedes it once published publicly.
  inputs.brand.url = "https://flakehub.com/f/dataheld/brand/*";
  outputs = _: { };
}
