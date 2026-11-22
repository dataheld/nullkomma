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
      readme = builtins.readFile (harness.root + "/README.md");
      # Plugins with options beyond `enable`: only their configs have blank lines.
      configs = lib.filterAttrs (_: lib.hasInfix "\n\n") harness.nullkomma.lib.configs;
    in
    {
      # README shows each plugin's options as `nix eval --raw .#lib.configs.<plugin>` prints them.
      nullkomma.nix.unit.tests.testReadmeShowsCurrentConfigs = {
        expr = {
          stale = lib.attrNames (lib.filterAttrs (_: c: !lib.hasInfix "```nix\n${c}```\n" readme) configs);
          blocks = lib.length (lib.splitString "```nix\n{\n  # Whether to enable the " readme) - 1;
        };
        expected = {
          stale = [ ];
          blocks = lib.length (lib.attrNames configs);
        };
      };
      checks.site = harness.linkcheck "documentation-site" site;
      checks.site-legal = harness.legalcheck "site-legal" site;
      checks.dogfood-workflow =
        pkgs.runCommand "nullkomma-dogfood-workflow" { nativeBuildInputs = [ pkgs.git ]; }
          ''
            ${harness.project config.nullkomma.src}
            mkdir nested
            cd nested
            ${lib.getExe config.taskRunners.default} quarto-render
            cmp ../_site/index.html ${site}/index.html
            touch "$out"
          '';
    };
}
