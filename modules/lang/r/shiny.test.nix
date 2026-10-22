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
            dependency = lib.elem "shiny" (perSystem fixtures.r).nullkomma.r.packages;
          };
          expected = {
            app = false;
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
              nativeBuildInputs = [ pkgs.curl ];
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
              cd "$TMPDIR"
              export R_LIBS_SITE="${pkgs.rPackages.pkgload}/library:${pkgs.rPackages.testthat}/library"
              ${enabled.apps.${system}.shiny.program} > server.log 2>&1 &
              pid=$!
              trap 'kill "$pid"; wait "$pid" || true' EXIT
              for attempt in {1..60}; do
                url=$(sed -n 's/^Listening on \(http:\/\/127[.]0[.]0[.]1:[0-9]*\).*$/\1/p' server.log)
                if [[ -n "$url" ]] && curl --noproxy '*' --fail --silent "$url" > response.html; then
                  grep -qF 'nullkomma Shiny fixture' response.html
                  touch "$out"
                  exit 0
                fi
                if ! kill -0 "$pid" 2>/dev/null; then
                  cat server.log >&2
                  exit 1
                fi
                sleep 1
              done
              cat server.log >&2
              echo 'Shiny did not become ready' >&2
              exit 1
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
