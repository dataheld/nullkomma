{
  partitions.dev.module.perSystem =
    { config, harness, ... }:
    {
      checks.site = harness.linkcheck "documentation-site" config.packages.site;
    };
}
