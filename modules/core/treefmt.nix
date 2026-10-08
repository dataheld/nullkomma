{ inputs, ... }:
{
  flake.flakeModules.default =
    { lib, ... }:
    {
      imports = [ inputs.treefmt-nix.flakeModule ];
      perSystem =
        { config, ... }:
        {
          treefmt = {
            programs = {
              # keep-sorted start block=yes
              actionlint.enable = lib.mkDefault true;
              deadnix.enable = lib.mkDefault true;
              jsonfmt.enable = lib.mkDefault true;
              keep-sorted.enable = lib.mkDefault true;
              mdformat = {
                enable = lib.mkDefault true;
                plugins = lib.mkDefault (ps: [
                  ps.mdformat-footnote
                  ps.mdformat-frontmatter
                  ps.mdformat-gfm
                  ps.mdformat-gfm-alerts
                ]);
              };
              nixfmt.enable = lib.mkDefault true;
              shellcheck.enable = lib.mkDefault true;
              shfmt.enable = lib.mkDefault true;
              toml-sort.enable = lib.mkDefault true;
              yamlfmt.enable = lib.mkDefault true;
              # keep-sorted end
            };
            # Generated files are formatted by their generator, not by treefmt.
            settings.excludes = lib.attrNames (lib.filterAttrs (_: f: f.enable) config.nullkomma.files);
          };
        };
    };
}
