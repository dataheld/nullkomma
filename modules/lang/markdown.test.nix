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
      # Shared defaults, as plugins contribute them; native files extend them.
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
        # Native `globs` must not widen treefmt's file selection.
        mkdir nested
        printf '[broken]()\n' > nested/bad.md
        printf '# Title\n\n<div>HTML is allowed.</div>\n\n' > allowed.md
        printf 'long line %.0s' {1..15} >> allowed.md
        printf '\n' >> allowed.md
        format allowed.md
        printf '# Title\n\n[broken]()\n' > 'literal[1].md'
        rejects MD042 'literal[1].md'
        printf 'MD042: false\n' > .markdownlint.yml
        printf 'globs: ["nested/bad.md"]\nignores: ["ignored.md"]\n' > .markdownlint-cli2.yaml
        printf '# Title\n\n[broken]()\n' > ignored.md
        format 'literal[1].md' allowed.md ignored.md
        printf 'MD013: true\n' > .markdownlint.yml
        rejects MD013 allowed.md
        mkdir nested-config
        cp allowed.md nested-config/allowed.md
        printf 'MD013: false\nMD033: true\n' > nested-config/.markdownlint.yaml
        rejects MD033 nested-config/allowed.md
        rm .markdownlint.yml
        format ignored.md
        rejects MD042 'literal[1].md'
        printf 'config: {MD042: false}\nglobs: ["nested/bad.md"]\n' > .markdownlint-cli2.yaml
        format 'literal[1].md' allowed.md
        touch "$out"
      '';
    };
}
