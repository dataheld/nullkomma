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
        runCheck
        ;
      fixture = root + "/tests/fixtures/r-shiny";
      enabled = callFlakeWith {
        nullkomma.r.extraPackages = [ "desc" ];
        nullkomma.r.shiny = {
          enable = true;
          function = "isolated_app";
          port = null;
        };
      } fixture;
      plain = callFlakeWith { } fixture;
      local = callFlakeWith {
        nullkomma.r.shiny = {
          enable = true;
          port = null;
        };
      } fixture;
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
            task = (perSystem fixtures.r).nullkomma.tasks ? shiny;
            taskAfter = (perSystem local).nullkomma.tasks.shiny.after;
            dependency = lib.elem "shiny" (perSystem fixtures.r).nullkomma.r.packages;
          };
          expected = {
            app = false;
            task = false;
            taskAfter = [ "r-namespace" ];
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
            localNetworking =
              (perSystem plain).nullkomma.checks.r-testthat.sandboxed.drvAttrs.__darwinAllowLocalNetworking
                or false;
          };
          expected = {
            small = [ ];
            smallBrowser = false;
            shinyMissing = [ ];
            shinyBrowser = true;
            localNetworking = pkgs.stdenv.isDarwin;
          };
        };
      };
      checks = {
        r-shiny =
          pkgs.runCommand "r-shiny"
            {
              nativeBuildInputs = [
                pkgs.curl
                pkgs.git
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
              substituteInPlace R/app.R --replace-fail 'nullkomma Shiny fixture' 'working-tree Shiny fixture'
              mkdir sub
              cd sub
              export R_LIBS_SITE="${pkgs.rPackages.pkgload}/library:${pkgs.rPackages.testthat}/library"
              for mode in installed working-tree; do
                if [[ "$mode" == installed ]]; then
                  command=${enabled.apps.${system}.shiny.program}
                  expected='nullkomma Shiny fixture'
                else
                  mkdir -p man
                  printf 'keep\n' > man/sentinel
                  command=${harness.task local "shiny"}
                  expected='working-tree Shiny fixture'
                fi
                : > server.log
                "$command" >> server.log 2>&1 &
                pid=$!
                trap 'kill "$pid"; wait "$pid" || true' EXIT
                ready=false
                for attempt in {1..60}; do
                  url=$(sed -n 's/^Listening on \(http:\/\/127[.]0[.]0[.]1:[0-9]*\).*$/\1/p' server.log)
                  if [[ -n "$url" ]] && curl --noproxy '*' --fail --silent "$url" > response.html; then
                    grep -qF "$expected" response.html
                    if [[ "$mode" == working-tree ]]; then
                      test -z "$(find man -type f -name '*.Rd' -print -quit)"
                      grep -qx keep man/sentinel
                    fi
                    ready=true
                    break
                  fi
                  if ! kill -0 "$pid" 2>/dev/null; then
                    cat server.log >&2
                    exit 1
                  fi
                  sleep 1
                done
                if [[ "$ready" != true ]]; then
                  cat server.log >&2
                  echo 'Shiny did not become ready' >&2
                  exit 1
                fi
                kill "$pid"
                wait "$pid" || true
                trap - EXIT
              done
              touch "$out"
            '';
        r-shinytest2 =
          pkgs.runCommand "r-shinytest2"
            {
              nativeBuildInputs = [ (perSystem plain).nullkomma.r.package ];
              __darwinAllowLocalNetworking = true;
            }
            ''
              ${harness.project fixture}
              # A stale installed copy must not shadow the source under pkgload.
              cp -R . "$TMPDIR/stale"
              substituteInPlace "$TMPDIR/stale/R/app.R" --replace-fail 'input$number * 2' 'input$number * 3'
              mkdir "$TMPDIR/library"
              R CMD INSTALL --library="$TMPDIR/library" "$TMPDIR/stale"
              R_LIBS_USER="$TMPDIR/library" ${runCheck plain "r-testthat"}
              # Installed tests must run apps from the installed package, not the source.
              cat > tests/testthat/test-installed.R <<'RS'
              test_that("apps come from the installed package", {
                writeLines('stop("the source was loaded")', test_path("../../R/zzz.R"))
                driver <- shinytest2::AppDriver$new(app, load_timeout = 60000)
                on.exit(driver$stop(), add = TRUE)
                expect_equal(driver$get_value(output = "doubled"), "2")
              })
              RS
              ${runCheck plain "r-testthat"} --installed
              touch $out
            '';
      };
    };
}
