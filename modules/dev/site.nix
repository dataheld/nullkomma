{
  partitions.dev.module.perSystem =
    {
      config,
      harness,
      ...
    }:
    let
      site = config.packages.site;
    in
    {
      checks.site = harness.linkcheck "documentation-site" site;
      checks.site-legal = harness.legalcheck "site-legal" site;
    };
}
