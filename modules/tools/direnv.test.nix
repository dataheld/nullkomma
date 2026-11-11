{
  partitions.dev.module.perSystem =
    { harness, ... }:
    let
      inherit (harness)
        perSystem
        plugins
        rawAt
        root
        ;
      envrc =
        partitions:
        (perSystem (
          rawAt root {
            imports = [ plugins.direnv ];
            nullkomma.direnv.enable = true;
            inherit partitions;
          }
        )).nullkomma.files.".envrc".text;
    in
    {
      nullkomma.nix.unit.tests.testDirenvWatchesPartitionSources = {
        expr = envrc {
          dev = {
            extraInputsFlake = root + "/dev";
            module = root + "/dev/module.nix";
          };
          docs.module = root + "/modules/dev/dogfood.nix";
          inline.module = { };
        };
        expected = ''
          # shellcheck shell=bash
          use flake
          watch_dir dev
          watch_file modules/dev/dogfood.nix
        '';
      };
    };
}
