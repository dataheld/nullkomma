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
        callFlakeWith
        fixtures
        perSystem
        root
        runCheck
        ;
      fixture = root + "/tests/fixtures/r-shiny";
      hello = callFlake (root + "/tests/fixtures/r-shiny-hello");
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
      nullkomma.tasks.try-shiny = {
        skip = true;
        raw = true;
        description = "Serve the Shiny hello example with pc-up-r-shiny, from a scratch copy you can edit";
        packages = [ pkgs.git ];
        command = ''
          root="$(git rev-parse --show-toplevel)"
          scratch="$(mktemp -d)"
          trap 'rm -rf "$scratch"' EXIT
          cp -R "$root/tests/fixtures/r-shiny-hello/." "$scratch"
          chmod -R u+w "$scratch"
          cd "$scratch"
          git init -q
          git add -A
          echo "Edit $scratch/R/app.R; the app reloads in the browser."
          nix run "path:$scratch#processTrees.${system}.r-shiny" \
            --override-input nullkomma "path:$root" --no-write-lock-file
        '';
      };
      nullkomma.nix.unit.tests = {
        testShinyHelloFixture = {
          expr = {
            app = hello.apps.${system} ? shiny;
            tree = lib.isString hello.processTrees.${system}.r-shiny.drvPath;
            probe = (perSystem hello).nullkomma.tasks.shiny.process ? readiness_probe;
          };
          expected = {
            app = true;
            tree = true;
            probe = true;
          };
        };
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
              export R_BROWSER="$TMPDIR/browser"
              cat > "$R_BROWSER" <<'SH'
              #!/bin/sh
              echo "$1" > "$TMPDIR/browsed"
              SH
              chmod +x "$R_BROWSER"
              # Own process groups, so killing a server also stops its watcher.
              set -m
              root="$(git rev-parse --show-toplevel)"
              # Waits until the server answers $1 with a page containing $2.
              serves() {
                for attempt in {1..60}; do
                  if [[ -n "$1" ]] && curl --noproxy '*' --fail --silent "$1" > response.html \
                    && grep -qF "$2" response.html; then
                    return
                  fi
                  if ! kill -0 "$pid" 2>/dev/null; then
                    cat server.log >&2
                    exit 1
                  fi
                  sleep 1
                done
                cat server.log >&2
                echo "Shiny did not serve: $2" >&2
                exit 1
              }
              for mode in installed working-tree process-tree; do
                rm -f "$TMPDIR/browsed"
                if [[ "$mode" == installed ]]; then
                  command=${enabled.apps.${system}.shiny.program}
                  expected='nullkomma Shiny fixture'
                else
                  mkdir -p man
                  printf 'keep\n' > man/sentinel
                  command=${harness.task local "shiny"}
                  expected='working-tree Shiny fixture'
                fi
                if [[ "$mode" == process-tree ]]; then
                  export NULLKOMMA_ROOT="$root" NULLKOMMA_PROCESSES=.nullkomma/processes/shiny
                  mkdir -p "$root/$NULLKOMMA_PROCESSES"
                  touch "$root/$NULLKOMMA_PROCESSES/r-namespace.ok"
                fi
                : > server.log
                "$command" >> server.log 2>&1 &
                pid=$!
                trap 'kill -- -"$pid"; wait "$pid" || true' EXIT
                for attempt in {1..60}; do
                  url=$(sed -n 's/^Listening on \(http:\/\/127[.]0[.]0[.]1:[0-9]*\).*$/\1/p' server.log)
                  [[ -n "$url" ]] && break
                  sleep 1
                done
                serves "$url" "$expected"
                if [[ "$mode" == installed ]]; then
                  test ! -e "$TMPDIR/browsed"
                else
                  test -z "$(find man -type f -name '*.Rd' -print -quit)"
                  grep -qx keep man/sentinel
                  for attempt in {1..10}; do
                    [[ -e "$TMPDIR/browsed" ]] && break
                    sleep 1
                  done
                  grep -qxF "$url" "$TMPDIR/browsed"
                fi
                if [[ "$mode" == process-tree ]]; then
                  bash -c ${lib.escapeShellArg (perSystem local).nullkomma.tasks.shiny.process.readiness_probe.exec.command}
                  substituteInPlace "$root/R/app.R" --replace-fail 'working-tree Shiny fixture' 'reloaded Shiny fixture'
                  touch "$root/$NULLKOMMA_PROCESSES/r-namespace.ok"
                  serves "$url" 'reloaded Shiny fixture'
                fi
                kill -- -"$pid"
                wait "$pid" || true
                trap - EXIT
                if [[ "$mode" == process-tree ]]; then
                  ! bash -c ${lib.escapeShellArg (perSystem local).nullkomma.tasks.shiny.process.readiness_probe.exec.command}
                fi
              done
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
