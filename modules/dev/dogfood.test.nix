{
  partitions.dev.module.perSystem =
    {
      config,
      harness,
      lib,
      pkgs,
      ...
    }:
    let
      site = config.packages.site;
    in
    {
      checks.site = harness.linkcheck "documentation-site" site;
      checks.site-legal = harness.legalcheck "site-legal" site;
      checks.dogfood-workflow =
        assert site.drvPath == config.nullkomma.tasks.nk-build-site.sandboxed.drvPath;
        assert config.nullkomma.tasks.nk-preview.watch.native;
        pkgs.runCommand "nullkomma-dogfood-workflow" { nativeBuildInputs = [ pkgs.git ]; } ''
          ${harness.project config.nullkomma.src}
          git init --quiet
          mkdir nested
          cd nested
          ${lib.getExe config.nullkomma.tasks.nk-build-site.package} --output-dir "$TMPDIR/local-site"
          cmp "$TMPDIR/local-site/index.html" ${site}/index.html
          touch "$out"
        '';
    };
}
