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
      md = root + "/tests/fixtures/md";
      # Shared defaults, as plugins contribute them.
      withDefaults = callFlakeWith {
        nullkomma.lint.markdown = {
          MD013 = false;
          MD033 = false;
        };
      } md;
    in
    {
      checks.markdown-native-config = pkgs.runCommand "markdown-native-config" { } ''
        ${project md}
        ${treefmt withDefaults}
        printf '# Title\n\n<div>HTML is allowed.</div>\n\n' > allowed.md
        printf 'long line %.0s' {1..15} >> allowed.md
        printf '\n' >> allowed.md
        format allowed.md
        printf '# Title\n\n[broken]()\n' > 'literal[1].md'
        rejects MD042 'literal[1].md'
        # A native config (`.rumdl.toml`, `.markdownlint.*`, …) replaces them, also in subdirectories.
        printf 'MD042: false\n' > .markdownlint.yml
        rejects MD013 allowed.md
        mkdir nested-config
        cp allowed.md nested-config/allowed.md
        printf 'MD013: false\nMD033: true\n' > nested-config/.markdownlint.yaml
        rejects MD033 nested-config/allowed.md
        touch "$out"
      '';
    };
}
