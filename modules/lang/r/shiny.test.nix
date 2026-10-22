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
        ;
      fixture = root + "/tests/fixtures/r-shiny";
      enabled = callFlakeWith {
        nullkomma.r.extraPackages = [ "desc" ];
        nullkomma.r.shiny = {
          enable = true;
          port = null;
        };
      } fixture;
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
      };
      checks.r-shiny =
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
    };
}
