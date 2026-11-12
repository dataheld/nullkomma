{
  partitions.dev.module.perSystem =
    {
      harness,
      lib,
      pkgs,
      system,
      ...
    }:
    let
      inherit (harness)
        callFlake
        perSystem
        plugins
        project
        rawAt
        root
        ;
      partitioned = root + "/tests/fixtures/dev-partition";
      envrc =
        partitions:
        (perSystem (
          rawAt root {
            imports = [ plugins.direnv ];
            nullkomma.direnv.enable = true;
            inherit partitions;
          }
        )).nullkomma.files.".envrc".sections.direnv;
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
      # Through the flake's outputs, as `nk` runs: `.gitignore` shows the partition's module applies.
      checks.direnv-watches-dev-partition =
        pkgs.runCommandLocal "nullkomma-direnv-watches-dev-partition" { }
          ''
            ${project partitioned}
            ${lib.getExe (callFlake partitioned).taskRunners.${system}.default} write-files
            grep -qx /scratch/ .gitignore
            grep -qx 'watch_dir dev' .envrc
            touch $out
          '';
    };
}
