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
        callFlakeWith
        fixtures
        perSystem
        root
        task
        ;
      fixture = root + "/tests/fixtures/r-shiny";
      enabled = callFlakeWith {
        nullkomma.r.extraPackages = [ "desc" ];
        nullkomma.r.shiny = {
          enable = true;
          function = "isolated_app";
          port = 38380;
        };
      } fixture;
      plain = callFlakeWith { nullkomma.r.shiny.enable = lib.mkForce false; } fixture;
      # Shares its first port with `enabled`, whose app holds it while the dev apps start.
      local = callFlakeWith { nullkomma.r.shiny.port = 38380; } fixture;
      single = callFlakeWith { nullkomma.r.shiny.devFunctions = lib.mkForce [ "app" ]; } fixture;
      mcpServer = (perSystem local).nullkomma.agents.mcpServers.r;
      heavy = [
        "shiny"
        "shinytest2"
        "chromote"
      ];
      closure = pkgs.closureInfo {
        rootPaths = [ (pkgs.writeText "shiny-program" enabled.apps.${system}.shiny.program) ];
      };
      invalid =
        name:
        (callFlakeWith {
          nullkomma.r.shiny = {
            enable = true;
            function = name;
          };
        } fixture).apps.${system}.shiny.program;
    in
    {
      nullkomma.nix.unit.tests = {
        testShinyIsOptIn = {
          expr = fixtures.r.apps.${system} ? shiny;
          expected = false;
        };
        # The lockfile alone sizes the R environment: no Shiny stack or browser unless declared.
        testLockSizesEnvironment = {
          expr = {
            small = lib.intersectLists heavy (perSystem fixtures.r).nullkomma.r.packages;
            smallBrowser = (perSystem fixtures.r).nullkomma.r.browser != null;
            shinyMissing = lib.subtractLists (perSystem plain).nullkomma.r.packages heavy;
            shinyBrowser = (perSystem plain).nullkomma.r.browser != null;
          };
          expected = {
            small = [ ];
            smallBrowser = false;
            shinyMissing = [ ];
            shinyBrowser = pkgs.stdenv.isLinux;
          };
        };
      };
      checks = {
        # Building the launcher runs ShellCheck on it.
        r-shiny-single-app = pkgs.writeText "r-shiny-single-app" (perSystem single)
        .process-compose.dev.settings.processes.r-shiny-browser.command;
        r-shiny =
          pkgs.runCommand "r-shiny"
            {
              # process-compose finds ports with lsof on macOS, which has it outside the sandbox.
              nativeBuildInputs = [
                pkgs.curl
                pkgs.git
                pkgs.jq
                pkgs.lsof
              ];
              __darwinAllowLocalNetworking = true;
            }
            ''
              ${harness.project fixture}
              if grep -E -- '-r-(pkgload|pak|languageserver|roxygen2|pkgdown|testthat|desc)-' ${closure}/store-paths; then
                echo 'Development-only packages leaked into the Shiny runtime' >&2
                exit 1
              fi
              fails 'must return a shiny.appobj' ${invalid "not_an_app"}
              fails 'is not an exported object' ${invalid "internal_app"}
              git init -q
              substituteInPlace R/app.R --replace-fail 'nullkomma Shiny fixture' 'working-tree Shiny fixture' \
                --replace-fail 'ui = shiny::fluidPage(shiny::h1' 'ui = function(req) shiny::fluidPage(warning("greeting requested"), shiny::h1'
              mkdir sub
              cd sub
              export R_LIBS_SITE="${pkgs.rPackages.pkgload}/library:${pkgs.rPackages.testthat}/library"
              export R_BROWSER="$TMPDIR/browser"
              printf '#!/bin/sh\necho "$1" >> "%s"\n' "$TMPDIR/opened" > "$R_BROWSER"
              chmod +x "$R_BROWSER"
              # A stopped `process-compose run` signals its whole process group, so the builder needs its own.
              set -m
              pids=()
              trap 'kill "''${pids[@]}" 2>/dev/null; wait || true' EXIT
              serve() {
                "$@" > server.log 2>&1 &
                pid=$!
                pids+=("$pid")
              }
              # Polls until $1 serves a page containing $2, which stays in response.html.
              await() {
                for attempt in {1..90}; do
                  if curl --noproxy '*' --fail --silent "$1" > response.html && grep -qF "$2" response.html; then
                    return
                  fi
                  kill -0 "$pid" 2>/dev/null || break
                  sleep 1
                done
                cat server.log >&2
                echo "$1 did not serve $2" >&2
                exit 1
              }
              stop() {
                kill "$pid"
                wait "$pid" || true
              }

              serve ${enabled.apps.${system}.shiny.program}
              await http://127.0.0.1:38380 'nullkomma Shiny fixture'
              if grep -qE 'shiny:disconnected|__SHINY_DEV_MODE__' response.html; then
                echo 'The installed app must run without development features' >&2
                exit 1
              fi

              mkdir -p man
              printf 'keep\n' > man/sentinel
              serve env PC_DISABLE_TUI=1 ${task local "r-run-app"}
              # The installed app holds 38380, so the first dev app steps past its sibling's 38381.
              await http://127.0.0.1:38382 'working-tree Shiny fixture'
              grep -qF shiny:disconnected response.html
              server=$(grep -oE '<script data-server="[0-9]+">' response.html)
              grep -qF __SHINY_DEV_MODE__ response.html
              if grep -qF shiny-autoreload.js response.html; then
                echo "Shiny's autoreload must stay off; restarts reload the apps" >&2
                exit 1
              fi
              await http://127.0.0.1:38381 'nullkomma greeting'
              grep -qE 'Warning.*greeting requested' server.log
              test -z "$(find man -type f -name '*.Rd' -print -quit)"
              grep -qx keep man/sentinel
              for attempt in {1..30}; do
                [[ "$(sort "$TMPDIR/opened" 2>/dev/null)" == $'http://127.0.0.1:38381\nhttp://127.0.0.1:38382' ]] && break
                sleep 1
              done
              diff <(printf '%s\n' http://127.0.0.1:38381 http://127.0.0.1:38382) <(sort "$TMPDIR/opened")

              # Edits restart the apps on their ports, so that open pages can reload.
              substituteInPlace ../R/app.R --replace-fail 'working-tree Shiny fixture' 'edited Shiny fixture'
              await http://127.0.0.1:38382 'edited Shiny fixture'
              if grep -qF "$server" response.html; then
                echo 'The edit did not restart the app' >&2
                exit 1
              fi
              await http://127.0.0.1:38381 'nullkomma greeting'
              if grep -qi 'address already in use' server.log; then
                cat server.log >&2
                exit 1
              fi

              call() {
                jq -nc --argjson id "$1" --arg name "$2" --argjson arguments "$3" \
                  '{jsonrpc: "2.0", $id, method: "tools/call", params: {$name, $arguments}}'
              }
              mcp() {
                {
                  echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check","version":"0"}}}'
                  printf '%s\n' "$@"
                  sleep 10
                } | ${lib.escapeShellArgs ([ mcpServer.command ] ++ mcpServer.args)} > mcp.jsonl
              }
              mcp "$(call 1 btw_tool_run_r '{"_intent":"check","code":"1 + 1"}')" \
                "$(call 2 btw_tool_docs_help_page '{"_intent":"check","topic":"runApp","package_name":"shiny"}')"
              jq -e 'select(.id == 1).result.content[0].text == "[1] 2"' mcp.jsonl
              jq -e 'select(.id == 2).result.content[0].text | contains("Run Shiny Application")' mcp.jsonl
              if ${mcpServer.command} -e 'quit(status = packageVersion("mcptools") < "1.0.1")'; then
                mcp "$(call 1 list_r_sessions '{}')" \
                  "$(call 2 select_r_session '{"session":1}')" \
                  "$(call 3 btw_tool_run_r '{"_intent":"check","code":"app_function"}')"
                jq -e 'select(.id == 1).result.content[0].text | split("\n") | length == 2' mcp.jsonl
                jq -e 'select(.id == 3).result.content[0].text | test("\"(app|greeting_app)\"")' mcp.jsonl
              fi
              stop
              touch "$out"
            '';
      }
      # Nixpkgs has no Chromium for macOS.
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        r-shinytest2 =
          pkgs.runCommand "r-shinytest2" { nativeBuildInputs = [ (perSystem plain).nullkomma.r.package ]; }
            ''
              ${harness.project fixture}
              # A stale installed copy must not shadow the source under pkgload.
              cp -R . "$TMPDIR/stale"
              substituteInPlace "$TMPDIR/stale/R/app.R" --replace-fail 'input$number * 2' 'input$number * 3'
              mkdir "$TMPDIR/library"
              R CMD INSTALL --library="$TMPDIR/library" "$TMPDIR/stale"
              R_LIBS_USER="$TMPDIR/library" ${task plain "r-test"}
              # shinytest2 skips tests when Chrome fails to start, and testthat then deletes their snapshots.
              if CHROMOTE_CHROME="$(command -v false)" ${task plain "r-test"}; then
                echo "r-test passed although Chrome failed to start" >&2
                exit 1
              fi
              test -e tests/testthat/_snaps/app/app-001.json
              # Installed tests must run apps from the installed package, not the source.
              cat > tests/testthat/test-installed.R <<'RS'
              test_that("apps come from the installed package", {
                writeLines('stop("the source was loaded")', test_path("../../R/zzz.R"))
                driver <- shinytest2::AppDriver$new(app, load_timeout = 60000)
                on.exit(driver$stop(), add = TRUE)
                expect_equal(driver$get_value(output = "doubled"), "2")
              })
              RS
              ${task plain "r-test"} --installed
              touch $out
            '';
      };
    };
}
