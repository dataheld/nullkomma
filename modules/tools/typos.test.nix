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
    in
    {
      checks.typos-nix-config = pkgs.runCommand "typos-nix-config" { } ''
        ${project (root + "/tests/fixtures/md")}
        ${treefmt (
          callFlakeWith {
            nullkomma.lint.typos.default.extend-words.foobaar = "foobaar";
          } (root + "/tests/fixtures/md")
        )}
        printf 'foobaar teh\n' > words.txt
        printf '[default.extend-words]\nteh = "teh"\n' > .typos.toml
        format --formatters typos words.txt
        grep -qx 'foobaar the' words.txt
        touch "$out"
      '';
    };
}
