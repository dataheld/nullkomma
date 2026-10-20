{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        fixtures
        project
        root
        treefmt
        ;
    in
    {
      checks.typos-native-config = pkgs.runCommand "typos-native-config" { } ''
        ${project (root + "/tests/fixtures/md")}
        ${treefmt fixtures.md}
        printf 'foobaar teh\n' > words.txt
        printf '[default.extend-words]\nfoobaar = "foobaar"\n[files]\nextend-exclude = ["ignored.txt"]\n' > .typos.toml
        printf 'teh\n' > ignored.txt
        format --formatters typos words.txt ignored.txt
        grep -qx 'foobaar the' words.txt
        grep -qx teh ignored.txt
        mkdir nested-config
        printf '[default.extend-words]\nfnd = "find"\n' > nested-config/.typos.toml
        printf 'fnd teh\n' > nested-config/words.txt
        format --formatters typos nested-config/words.txt
        grep -qx 'find the' nested-config/words.txt
        touch "$out"
      '';
    };
}
