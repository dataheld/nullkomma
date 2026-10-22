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
      checks.markdown-nix-config = pkgs.runCommand "markdown-nix-config" { } ''
        ${project md}
        ${treefmt withDefaults}
        printf '# Title\n\n<div>HTML is allowed.</div>\n\n' > allowed.md
        printf 'long line %.0s' {1..15} >> allowed.md
        printf '\n' >> allowed.md
        format allowed.md
        printf '# Title\n\n[broken]()\n' > 'literal[1].md'
        rejects MD042 'literal[1].md'
        # Native files cannot replace Nix policy, even in subdirectories.
        printf 'MD042: false\n' > .markdownlint.yml
        format allowed.md
        rejects MD042 'literal[1].md'
        mkdir nested-config
        cp allowed.md nested-config/allowed.md
        printf 'MD013: false\nMD033: true\n' > nested-config/.markdownlint.yaml
        format nested-config/allowed.md
        printf '[global]\ndisable = ["MD042"]\n' > .rumdl.toml
        printf '[global]\ndisable = ["MD013"]\n' > nested-config/.rumdl.toml
        rejects MD042 'literal[1].md'
        format nested-config/allowed.md
        touch "$out"
      '';
    };
}
