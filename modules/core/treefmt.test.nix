{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        callFlakeWith
        project
        root
        treefmt
        ;
      flake = callFlakeWith {
        nullkomma.generatedPaths = [ "generated/**" ];
        perSystem.nullkomma.files."managed" = {
          mode = "generated";
          directory = true;
          source = root + "/tests/fixtures/r-brand/assets";
        };
      } (root + "/tests/fixtures/md");
    in
    {
      checks.treefmt-skips-generated = pkgs.runCommand "treefmt-skips-generated" { } ''
        ${project (root + "/tests/fixtures/md")}
        ${treefmt flake}
        for directory in managed/nested generated/nested; do
          mkdir -p "$directory"
          printf 'broken: [\n' > "$directory/bad.yaml"
          printf '[broken]()\n' > "$directory/bad.md"
        done
        format
        format managed/nested/bad.yaml generated/nested/bad.md
        touch "$out"
      '';
    };
}
