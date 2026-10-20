{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        callFlakeWith
        project
        root
        test
        ;
      fixture = root + "/tests/fixtures/md";
      jscpd = test (callFlakeWith { nullkomma.generatedPaths = [ "generated/**" ]; } fixture) "jscpd";
    in
    {
      checks.jscpd-native-config = pkgs.runCommand "jscpd-native-config" { } ''
        ${project fixture}
        mkdir generated custom
        cat > generated/one.R <<'R'
        greet <- function(names, prefix) {
          greetings <- character()
          for (name in names) {
            normalized <- tolower(trimws(name))
            greeting <- paste0(prefix, normalized)
            message(greeting)
            greetings <- c(greetings, greeting)
          }
          paste(greetings, collapse = "\n")
        }
        R
        for copy in generated/two.R custom/one.R custom/two.R; do
          cp generated/one.R "$copy"
        done
        fails threshold ${jscpd}
        # Native ignores extend the generated paths.
        printf '{"ignore":["custom/**"]}\n' > .jscpd.json
        ${jscpd}
        cp custom/one.R one.R
        cp custom/one.R two.R
        fails threshold ${jscpd}
        printf '{"ignore":["custom/**"],"threshold":100}\n' > .jscpd.json
        ${jscpd}
        touch "$out"
      '';
    };
}
