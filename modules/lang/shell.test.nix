{
  partitions.dev.module.perSystem =
    {
      harness,
      pkgs,
      system,
      ...
    }:
    {
      checks.shellcheck-nix-config = pkgs.runCommand "shellcheck-nix-config" { } ''
        ${harness.project (harness.root + "/tests/fixtures/shell")}
        ${harness.treefmt (
          harness.callFlakeWith {
            perSystem.treefmt.settings.formatter.shellcheck.options = [ "--exclude=SC2086" ];
          } (harness.root + "/tests/fixtures/shell")
        )}
        printf 'disable=SC2154\n' > .shellcheckrc
        printf '#!/usr/bin/env bash\necho "$undefined"\n' > bad.sh
        rejects SC2154 --formatters shellcheck bad.sh
        printf '#!/usr/bin/env bash\nname=hello\necho $name\n' > allowed.sh
        format --formatters shellcheck allowed.sh
        touch "$out"
      '';
      checks.bats-rejects-failing-tests = pkgs.testers.testBuildFailure' {
        name = "nullkomma-bats-rejects-failing-tests";
        drv =
          (harness.callFlakeWith { nullkomma.shell.bats.testDir = "failing"; } (
            harness.root + "/tests/fixtures/shell"
          )).checks.${system}.bats;
        expectedBuilderExitCode = 1;
        expectedBuilderLogEntries = [ "not ok 1 fails on purpose" ];
      };
    };
}
