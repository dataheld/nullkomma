{
  partitions.dev.module.perSystem =
    {
      harness,
      pkgs,
      system,
      ...
    }:
    {
      checks.bats-rejects-failing-tests = pkgs.testers.testBuildFailure' {
        name = "nullkomma-bats-rejects-failing-tests";
        drv =
          (harness.callFlakeWith { nullkomma.shell.bats.testDir = "failing"; } (
            harness.root + "/tests/fixtures/shell"
          )).checks.${system}.test-bats;
        expectedBuilderExitCode = 1;
        expectedBuilderLogEntries = [ "not ok 1 fails on purpose" ];
      };
    };
}
