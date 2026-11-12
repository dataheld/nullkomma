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
      fixture = root + "/templates/default";
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
        cat > generated/one.nix <<'NIX'
        { lib, names, prefix }:
        let
          normalized = map (name: lib.toLower (lib.trim name)) names;
          greetings = map (name: "''${prefix}''${name}") normalized;
          counted = lib.imap1 (index: greeting: "''${toString index}. ''${greeting}") greetings;
        in
        {
          inherit greetings counted;
          text = lib.concatStringsSep "\n" counted;
        }
        NIX
        for copy in generated/two.nix custom/one.nix custom/two.nix; do
          cp generated/one.nix "$copy"
        done
        fails threshold ${jscpd}
        # Native configuration cannot relax the threshold.
        printf '{"ignore":["**"],"threshold":100}\n' > .jscpd.json
        printf '{"jscpd":{"threshold":100,"ignore":["**"]}}\n' > package.json
        mkdir .config
        printf '{"threshold":100}\n' > .config/jscpd.json
        fails threshold ${jscpd}
        ${customized}
        ${relaxed}
        touch "$out"
      '';
    };
}
