{ self, ... }:
{
  partitions.dev.module.perSystem =
    {
      config,
      harness,
      lib,
      pkgs,
      system,
      ...
    }:
    let
      site = config.packages.site;
    in
    {
      checks.site = harness.linkcheck "documentation-site" site;
      checks.site-legal = harness.legalcheck "site-legal" site;
      checks.dogfood-workflow =
        assert site.drvPath == config.nullkomma.tasks.build-site.sandboxed.drvPath;
        assert self.processTrees.${system}.preview.drvPath == config.processTrees.preview.drvPath;
        assert config.nullkomma.tasks.preview.watch.native;
        assert config.processTrees.preview.processes.preview.watch == null;
        pkgs.runCommand "nullkomma-dogfood-workflow" { nativeBuildInputs = [ pkgs.git ]; } ''
          ${harness.project config.nullkomma.src}
          git init --quiet
          ${lib.getExe config.taskRunners.default} > menu
          grep -qF dev-preview menu
          if grep -qF watch-preview menu; then exit 1; fi
          mkdir nested
          cd nested
          ${lib.getExe config.nullkomma.tasks.build-site.package} --output-dir "$TMPDIR/local-site"
          cmp "$TMPDIR/local-site/index.html" ${site}/index.html
          touch "$out"
        '';
    };
}
