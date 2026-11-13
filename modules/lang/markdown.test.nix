{
  partitions.dev.module.perSystem =
    { harness, pkgs, ... }:
    let
      inherit (harness)
        callFlakeWith
        perSystem
        project
        root
        treefmt
        ;
      template = root + "/templates/default";
      # Shared defaults, as plugins contribute them.
      withDefaults = callFlakeWith {
        nullkomma.lint.markdown = {
          MD013 = false;
          MD033 = false;
        };
      } template;
    in
    {
      checks.markdown-nix-config = pkgs.runCommand "markdown-nix-config" { } ''
        ${project template}
        ${treefmt withDefaults}
        printf '# Title\n\n<div>HTML is allowed.</div>\n\n' > allowed.md
        printf 'long line %.0s' {1..15} >> allowed.md
        printf '\n' >> allowed.md
        format allowed.md
        printf '# Title\n\n[broken]()\n' > 'literal[1].md'
        rejects MD042 'literal[1].md'
        # Native files cannot replace Nix policy, even in subdirectories.
        printf 'MD042: false\n' > .markdownlint.yml
        printf '[global]\ndisable = ["MD042"]\n' > .rumdl.toml
        rejects MD042 'literal[1].md'
        mkdir nested-config
        cp allowed.md nested-config/allowed.md
        printf 'MD013: false\nMD033: true\n' > nested-config/.markdownlint.yaml
        format nested-config/allowed.md
        touch "$out"
      '';
      # Editors report what the lint check reports, whatever native files say.
      checks.markdown-language-server =
        let
          inherit ((perSystem withDefaults).nullkomma) editor files;
        in
        pkgs.runCommand "markdown-language-server"
          {
            nativeBuildInputs = [
              pkgs.neovim-unwrapped
              editor.languageServers.rumdl.package
            ];
          }
          ''
            ${project template}
            printf '# Title\n\n<div>HTML is allowed.</div>\n\n[broken]()\n\n' > page.md
            printf 'long line %.0s' {1..15} >> page.md
            printf 'end\n' >> page.md
            printf 'MD042: false\n' > .markdownlint.yml
            printf '[global]\ndisable = ["MD042"]\n' > .rumdl.toml
            nvim --clean -l ${pkgs.writeText "check.lua" ''
              dofile("${files.".nvim.lua".source}")
              vim.cmd.edit("page.md")
              vim.bo.filetype = "markdown"
              assert(vim.wait(60000, function() return #vim.diagnostic.get(0) > 0 end))
              local codes = vim.tbl_map(function(d) return d.code end, vim.diagnostic.get(0))
              assert(vim.deep_equal(codes, { "MD042" }), vim.inspect(codes))
            ''}
            touch "$out"
          '';
    };
}
