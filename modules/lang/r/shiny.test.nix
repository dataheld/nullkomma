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
      local = callFlakeWith { nullkomma.r.shiny.port = 38381; } fixture;
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
          expr = {
            app = fixtures.r.apps.${system} ? shiny;
            task = (perSystem fixtures.r).process-compose.dev.settings.processes ? shiny;
            taskAfter = lib.attrNames (perSystem local)
              .process-compose.dev.settings.processes.r-run-app.depends_on;
            dependency = lib.elem "shiny" (perSystem fixtures.r).nullkomma.r.packages;
          };
          expected = {
            app = false;
            task = false;
            taskAfter = [
              "r-shiny-app"
              "r-shiny-greeting_app"
            ];
            dependency = false;
          };
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
        r-shiny =
          pkgs.runCommand "r-shiny"
            {
              # process-compose finds ports with lsof on macOS, which has it outside the sandbox.
              nativeBuildInputs = [
                pkgs.curl
                pkgs.git
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
              serve() {
                "$@" > server.log 2>&1 &
                pid=$!
                trap 'kill "$pid"; wait "$pid" || true' EXIT
              }
              # Polls until $1 serves a page containing $2, which stays in response.html.
              await() {
                for attempt in {1..60}; do
                  if curl --noproxy '*' --fail --silent "$1" > response.html; then
                    grep -qF "$2" response.html
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
                trap - EXIT
              }

              serve ${enabled.apps.${system}.shiny.program}
              await http://127.0.0.1:38380 'nullkomma Shiny fixture'
              if grep -qE 'shiny:disconnected|__SHINY_DEV_MODE__' response.html; then
                echo 'The installed app must run without development features' >&2
                exit 1
              fi
              stop

              mkdir -p man
              printf 'keep\n' > man/sentinel
              serve env PC_DISABLE_TUI=1 ${task local "r-run-app"}
              await http://127.0.0.1:38381 'working-tree Shiny fixture'
              grep -qF shiny:disconnected response.html
              grep -qF __SHINY_DEV_MODE__ response.html
              if grep -qF shiny-autoreload.js response.html; then
                echo "Shiny's autoreload must stay off; restarts reload the apps" >&2
                exit 1
              fi
              await http://127.0.0.1:38382 'nullkomma greeting'
              grep -qE 'Warning.*greeting requested' server.log
              test -z "$(find man -type f -name '*.Rd' -print -quit)"
              grep -qx keep man/sentinel
              for attempt in {1..30}; do
                [[ "$(sort "$TMPDIR/opened" 2>/dev/null)" == $'http://127.0.0.1:38381\nhttp://127.0.0.1:38382' ]] && break
                sleep 1
              done
              diff <(printf '%s\n' http://127.0.0.1:38381 http://127.0.0.1:38382) <(sort "$TMPDIR/opened")
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
