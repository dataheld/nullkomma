{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        callFlakeWith
        project
        root
        task
        ;
      fixture = root + "/tests/fixtures/md";
      jscpd = task (callFlakeWith { nullkomma.generatedPaths = [ "generated/**" ]; } fixture) "jscpd";
      customized = task (callFlakeWith {
        nullkomma.generatedPaths = [ "generated/**" ];
        nullkomma.lint.jscpd.ignore = [ "custom/**" ];
      } fixture) "jscpd";
      relaxed = task (callFlakeWith { nullkomma.lint.jscpd.threshold = 100; } fixture) "jscpd";
    in
    {
      checks.jscpd-nix-config = pkgs.runCommand "jscpd-nix-config" { } ''
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
        # Native configuration cannot relax the threshold.
        printf '{"ignore":["**"],"threshold":100}\n' > .jscpd.json
        fails threshold ${jscpd}
        rm .jscpd.json
        printf '{"jscpd":{"threshold":100,"ignore":["**"]}}\n' > package.json
        mkdir .config
        printf '{"threshold":100}\n' > .config/jscpd.json
        fails threshold ${jscpd}
        ${customized}
        cp custom/one.R one.R
        cp custom/one.R two.R
        fails threshold ${customized}
        ${relaxed}
        touch "$out"
      '';
    };
}
