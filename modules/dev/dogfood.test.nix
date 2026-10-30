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
        pkgs.runCommand "nullkomma-dogfood-workflow" { nativeBuildInputs = [ pkgs.git ]; }
          ''
            ${harness.project config.nullkomma.src}
            git init --quiet
            mkdir nested
            cd nested
            ${lib.getExe config.taskRunners.default} build-site
            cmp ../_site/index.html ${site}/index.html
            touch "$out"
          '';
    };
}
