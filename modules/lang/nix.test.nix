{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      system,
      ...
    }:
    let
      inherit (harness)
        plugins
        perSystem
        raw
        summary
        ;
      nix =
        module:
        raw {
          imports = [
            plugins.nix
            module
          ];
          nullkomma.nix.enable = true;
        };
      withTests = nix {
        perSystem.nullkomma.nix.unit.tests.testTrue = {
          expr = true;
          expected = true;
        };
      };
    in
    {
      nullkomma.nix.unit.tests = {
        testNixUnitTestsBecomeTest = {
          expr = {
            checks = lib.filter (lib.hasPrefix "test-") (summary withTests).checks;
            tests = lib.attrNames withTests.tests.systems.${system};
            schema = withTests.schemas ? tests;
            withoutTests = (nix { }).tests.systems.${system};
          };
          expected = {
            checks = [ "test-nix-unit" ];
            tests = [ "testTrue" ];
            schema = true;
            withoutTests = { };
          };
        };
        testNixPluginWorksWithoutOthers = {
          expr = {
            inherit (summary (nix { })) formatters;
            inherit ((perSystem (nix { })).nullkomma.editor.languageServers.nixd) settings;
          };
          expected = {
            formatters = [
              "deadnix"
              "nixf-diagnose"
              "nixfmt"
            ];
            settings.nixd.formatting.command = [
              "treefmt"
              "--stdin"
              "{file}"
            ];
          };
        };
      };
    };
}
