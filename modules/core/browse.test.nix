{
  partitions.dev.module.perSystem =
    {
      harness,
      pkgs,
      ...
    }:
    let
      inherit (harness) perSystem raw;
      flake =
        server:
        raw {
          perSystem.nullkomma.browse = {
            servers = [ "server" ];
            command = "${pkgs.writeShellScript "browser" ''echo "$1" >> "$TMPDIR/opened"''}";
          };
          perSystem.process-compose.dev.settings.processes.server = server;
        };
      browsed = flake {
        namespace = "demo";
        command = ''
          echo 'see https://example.org'
          printf 'Listening on \e[4mhttp://0.0.0.0:3838\e[24m now\n'
          echo started >> started
          exec sleep 600
        '';
        ready_log_line = "Listening on";
        watch.paths = [ { path = "trigger"; } ];
      };
    in
    {
      nullkomma.nix.unit.tests.testBrowsedServerNeedsReadyLine = {
        expr =
          (perSystem (flake {
            command = "true";
          })).process-compose.dev.settings.processes.server-browser.command;
        expectedError.msg = "server needs a ready_log_line";
      };
      checks.browse = pkgs.runCommand "nullkomma-browse" { } ''
        ${harness.project (harness.root + "/templates/default")}
        touch trigger
        ${harness.watching browsed "server"}
        awaiting 'test -s "$TMPDIR/opened"' "$server"
        test "$(cat "$TMPDIR/opened")" = http://127.0.0.1:3838
        test "${(perSystem browsed).process-compose.dev.settings.processes.server-browser.namespace}" = demo
        # Restarts reuse the open page.
        echo >> trigger
        restarted() { [ "$(wc -l < started)" -eq 2 ]; }
        awaiting restarted "$server"
        sleep 2
        test "$(wc -l < "$TMPDIR/opened")" -eq 1
        touch $out
      '';
    };
}
