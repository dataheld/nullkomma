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
            nullkomma.lint.typos = {
              default.extend-words.foobaar = "foobaar";
              files.extend-exclude = [ "ignored.txt" ];
            };
          } (root + "/tests/fixtures/md")
        )}
        printf 'foobaar teh\n' > words.txt
        printf '[default.extend-words]\nteh = "teh"\n' > .typos.toml
        printf 'teh\n' > ignored.txt
        format --formatters typos words.txt ignored.txt
        grep -qx 'foobaar the' words.txt
        grep -qx teh ignored.txt
        mkdir nested-config
        printf '[default.extend-words]\nteh = "teh"\n' > nested-config/.typos.toml
        printf 'teh\n' > nested-config/words.txt
        format --formatters typos nested-config/words.txt
        grep -qx 'the' nested-config/words.txt
        touch "$out"
      '';
    };
}
