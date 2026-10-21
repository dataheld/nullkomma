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
        # `.markdownlint-cli2.*` rules extend the shared ones; its `globs` must not widen treefmt's selection.
        mkdir nested
        printf '[broken]()\n' > nested/bad.md
        printf 'config: {MD042: false}\nglobs: ["nested/bad.md"]\n' > .markdownlint-cli2.yaml
        format 'literal[1].md' allowed.md
        printf 'ignores: ["ignored.md"]\n' > .markdownlint-cli2.yaml
        cp 'literal[1].md' ignored.md
        format ignored.md
        # `.markdownlint.*` replaces them, also in subdirectories.
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
