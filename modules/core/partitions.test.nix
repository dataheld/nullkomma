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
        callFlake
        callFlakeWith
        perSystem
        root
        ;
      devOnly = root + "/tests/fixtures/dev-only";
      served = flake: {
        outputs = lib.mapAttrs (_: output: lib.attrNames output.${system}) {
          inherit (flake)
            checks
            devShells
            packages
            processTrees
            taskRunners
            ;
          tests = flake.tests.systems;
        };
        formatter = lib.isDerivation flake.formatter.${system};
        envrc = (perSystem flake).nullkomma.files.".envrc".text;
      };
    in
    {
      nullkomma.nix.unit.tests.testDevOnlyNullkommaServesOutputs = {
        expr = map served [
          (callFlake devOnly)
          # Projects may still disable nullkomma's partition defaults by their key.
          (callFlakeWith { disabledModules = [ { key = "nullkomma#devPartition"; } ]; } devOnly)
        ];
        expected = lib.replicate 2 {
          outputs = {
            checks = [
              "jscpd"
              "project-files"
              "treefmt"
            ];
            devShells = [ "default" ];
            packages = [ "dev" ];
            processTrees = [ "dev" ];
            taskRunners = [ "default" ];
            tests = [ ];
          };
          formatter = true;
          envrc = ''
            # shellcheck shell=bash
            use flake
            watch_dir dev
          '';
        };
      };
    };
}
